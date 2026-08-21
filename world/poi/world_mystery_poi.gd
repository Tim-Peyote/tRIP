class_name WorldMysteryPOI
extends StaticBody3D

const RECORDED_WIND := preload("res://assets/third_party/open_game_art_audio/wind_gust.ogg")
const RECORDED_CAVERN := preload("res://assets/third_party/open_game_art_audio/dark_cavern.ogg")
const RECORDED_ROOTS := preload("res://assets/third_party/open_game_art_audio/dungeon_ambience.ogg")
const RECORDED_UNCANNY_FOREST := preload("res://assets/third_party/open_game_art_audio/creepy_forest.ogg")

signal discovered(definition: WorldMysteryDefinition)
signal event_started(definition: WorldMysteryDefinition, instruction: String)
signal event_failed(definition: WorldMysteryDefinition, failure_text: String)
signal event_progressed(definition: WorldMysteryDefinition, progress: float, pressure: float)

var definition: WorldMysteryDefinition
var _interactable: InteractableComponent
var _was_discovered: bool = false
var _event_active: bool = false
var _event_progress: float = 0.0
var _pressure: float = 0.0
var _actor: FirstPersonController
var _event_center: Vector3
var _pulse_root: Node3D
var _event_light: OmniLight3D
var _event_audio: AudioStreamPlayer3D
var _last_emitted_step: int = -1
var _reveal_nodes: Array[Node] = []
var _event_rings: Array[MeshInstance3D] = []
var _rule_visuals: Array[MeshInstance3D] = []


func configure(value: WorldMysteryDefinition, interaction_center: Vector3 = Vector3.ZERO) -> void:
	definition = value
	_event_center = interaction_center
	collision_layer = 4
	collision_mask = 0
	_interactable = InteractableComponent.new()
	_interactable.name = "InteractableComponent"
	_interactable.object_name = definition.display_name if definition != null else "Неизвестный след"
	_interactable.primary_verb = "Изучить тайну места"
	_interactable.hold_duration = 0.85
	_interactable.inspection_description = definition.description if definition != null else "След не подчиняется обычной географии."
	_interactable.interaction_completed.connect(_on_interaction_completed)
	add_child(_interactable)
	var collision := CollisionShape3D.new()
	collision.name = "MysteryCollision"
	var shape := CylinderShape3D.new()
	shape.radius = 2.1
	shape.height = 3.8
	collision.shape = shape
	collision.position = interaction_center + Vector3.UP * 1.9
	add_child(collision)
	_build_event_presentation()
	set_process(false)


func get_interaction_prompt(_actor: Node) -> String:
	if _was_discovered:
		return "Сверить запись: %s" % _interactable.object_name
	if _event_active:
		return definition.event_instruction
	return "Изучить: %s" % _interactable.object_name


func register_reveal_node(node: Node) -> void:
	if node == null or node in _reveal_nodes:
		return
	_reveal_nodes.append(node)
	if node.has_method("set_revealed"):
		node.call("set_revealed", _was_discovered)


func set_completed(value: bool) -> void:
	_was_discovered = value
	if _interactable != null:
		_interactable.primary_verb = "Сверить открытую запись" if value else "Изучить тайну места"
	for node: Node in _reveal_nodes:
		if is_instance_valid(node) and node.has_method("set_revealed"):
			node.call("set_revealed", value)


func is_completed() -> bool:
	return _was_discovered


func simulate_resolution() -> bool:
	if definition == null or _was_discovered:
		return false
	_resolve_event()
	return true


func _on_interaction_completed(actor: Node, _action: StringName) -> void:
	if definition == null or _was_discovered:
		return
	if not actor is FirstPersonController:
		_resolve_event()
		return
	_actor = actor as FirstPersonController
	_event_active = true
	_event_progress = 0.0
	_pressure = 0.0
	_last_emitted_step = -1
	_interactable.primary_verb = definition.event_instruction
	_set_presentation_active(true)
	set_process(true)
	event_started.emit(definition, definition.event_instruction)


func _process(delta: float) -> void:
	if not _event_active or not is_instance_valid(_actor):
		return
	var distance := _actor.global_position.distance_to(_event_center)
	if distance > definition.danger_radius * 1.65:
		_fail_event()
		return
	var obeying := _is_obeying_rule(distance)
	if obeying:
		_event_progress = minf(_event_progress + delta / definition.event_duration, 1.0)
		_pressure = move_toward(_pressure, 0.0, delta * 0.18)
	else:
		_event_progress = maxf(_event_progress - delta * 0.08, 0.0)
		_pressure = minf(_pressure + delta * definition.pressure_rate, 1.0)
	_update_presentation()
	var progress_step := int(floor(_event_progress * 10.0))
	if progress_step != _last_emitted_step:
		_last_emitted_step = progress_step
		event_progressed.emit(definition, _event_progress, _pressure)
	if _pressure >= 1.0:
		_fail_event()
	elif _event_progress >= 1.0:
		_resolve_event()


func _is_obeying_rule(distance: float) -> bool:
	var speed := _actor.get_planar_speed()
	match definition.event_rule:
		WorldMysteryDefinition.EventRule.CROUCH_AND_LISTEN:
			return _actor.is_crouched() and speed < 0.7 and distance <= definition.danger_radius
		WorldMysteryDefinition.EventRule.KEEP_WALKING:
			return speed >= 0.8 and speed <= _actor.walk_speed * 1.25 and distance <= definition.danger_radius
		WorldMysteryDefinition.EventRule.RETREAT_WITHOUT_RUNNING:
			return distance >= definition.danger_radius * 0.62 and distance <= definition.danger_radius * 1.35 and speed <= _actor.walk_speed * 1.15
		WorldMysteryDefinition.EventRule.APPROACH_SLOWLY:
			return distance <= definition.danger_radius * 0.58 and speed <= _actor.crouch_speed * 1.35
		_:
			return speed < 0.18 and distance <= definition.danger_radius


func _resolve_event() -> void:
	_event_active = false
	_was_discovered = true
	set_process(false)
	_interactable.primary_verb = "Сверить открытую запись"
	for node: Node in _reveal_nodes:
		if is_instance_valid(node) and node.has_method("set_revealed"):
			node.call("set_revealed", true)
	_set_presentation_active(false)
	discovered.emit(definition)


func _fail_event() -> void:
	_event_active = false
	set_process(false)
	_interactable.primary_verb = "Повторить настройку места"
	_set_presentation_active(false)
	if is_instance_valid(_actor):
		var away := (_actor.global_position - _event_center).normalized()
		if away.length_squared() < 0.1:
			away = Vector3.FORWARD
		_actor.global_position += away * 1.8
		_actor.velocity = Vector3.ZERO
	event_failed.emit(definition, definition.failure_text)


func _exit_tree() -> void:
	# AudioStreamPlaybackWAV can outlive its owner for one mixer cycle unless the
	# looping stream is explicitly detached before the POI leaves SceneTree.
	if is_instance_valid(_event_audio):
		_event_audio.stop()
		_event_audio.stream = null


func _build_event_presentation() -> void:
	_pulse_root = Node3D.new()
	_pulse_root.name = "MysteryEventPulse"
	_pulse_root.position = _event_center + Vector3.UP * 0.12
	add_child(_pulse_root)
	for index: int in 3:
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 1.25 + float(index) * 0.72
		mesh.outer_radius = mesh.inner_radius + 0.035
		mesh.rings = 32
		mesh.ring_segments = 5
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(definition.event_color, 0.58 - float(index) * 0.12)
		material.emission_enabled = true
		material.emission = definition.event_color
		material.emission_energy_multiplier = 1.4
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material = material
		ring.mesh = mesh
		ring.name = "EventRing_%02d" % index
		_pulse_root.add_child(ring)
		_event_rings.append(ring)
	_build_rule_visuals()
	_event_light = OmniLight3D.new()
	_event_light.name = "MysteryEventLight"
	_event_light.light_color = definition.event_color
	_event_light.light_energy = 0.0
	_event_light.omni_range = definition.danger_radius
	_event_light.position = _event_center + Vector3.UP * 1.1
	add_child(_event_light)
	_event_audio = AudioStreamPlayer3D.new()
	_event_audio.name = "MysteryEventAudio"
	_event_audio.bus = &"Perception"
	_event_audio.stream = _get_recorded_event_layer(definition.event_rule)
	if _event_audio.stream is AudioStreamOggVorbis:
		(_event_audio.stream as AudioStreamOggVorbis).loop = true
	_event_audio.pitch_scale = clampf(definition.audio_pitch, 0.88, 1.12)
	_event_audio.volume_db = -24.0
	_event_audio.max_distance = definition.danger_radius * 2.2
	_event_audio.position = _event_center + Vector3.UP
	add_child(_event_audio)
	_set_presentation_active(false)


func _set_presentation_active(value: bool) -> void:
	if _pulse_root != null:
		_pulse_root.visible = value
	if _event_light != null:
		_event_light.light_energy = 2.2 if value else 0.0
	if _event_audio != null:
		if value:
			_event_audio.play()
		else:
			_event_audio.stop()


func _update_presentation() -> void:
	var time := Time.get_ticks_msec() * 0.001
	if _pulse_root != null:
		_pulse_root.rotation.y = time * (0.18 + definition.audio_pitch * 0.05) * (1.8 if definition.event_rule == WorldMysteryDefinition.EventRule.KEEP_WALKING else 1.0)
		for index: int in _event_rings.size():
			var ring := _event_rings[index]
			var wave := 1.0 + sin(time * (1.8 + float(index) * 0.27) + float(index)) * 0.08
			ring.scale = Vector3.ONE * wave * lerpf(0.88, 1.16, _pressure)
		for index: int in _rule_visuals.size():
			var visual := _rule_visuals[index]
			visual.position.y = float(visual.get_meta(&"base_y", visual.position.y)) + sin(time * (1.3 + float(index) * 0.11) + float(index)) * 0.08
			visual.rotation.z = sin(time * 0.8 + float(index)) * 0.08
	if _event_light != null:
		_event_light.light_energy = lerpf(1.7, 5.4, _pressure) + sin(time * 4.0) * 0.35
	if _event_audio != null:
		_event_audio.volume_db = lerpf(-24.0, -14.0, _pressure)


func _build_rule_visuals() -> void:
	var count := 7 if definition.event_rule == WorldMysteryDefinition.EventRule.CROUCH_AND_LISTEN else 5
	for index: int in count:
		var visual := MeshInstance3D.new()
		visual.name = "RuleEcho_%02d" % index
		var mesh: Mesh
		match definition.event_rule:
			WorldMysteryDefinition.EventRule.CROUCH_AND_LISTEN:
				var spore := SphereMesh.new()
				spore.radius = 0.09 + float(index % 3) * 0.045
				spore.height = spore.radius * 2.0
				spore.radial_segments = 6
				spore.rings = 4
				mesh = spore
			WorldMysteryDefinition.EventRule.KEEP_WALKING:
				mesh = BiomeMeshLibrary.create_false_beast_echo()
			WorldMysteryDefinition.EventRule.RETREAT_WITHOUT_RUNNING:
				var remnant := QuadMesh.new()
				remnant.size = Vector2(1.1 + float(index % 2) * 0.55, 1.8)
				mesh = remnant
			WorldMysteryDefinition.EventRule.APPROACH_SLOWLY:
				var reflection := CylinderMesh.new()
				reflection.top_radius = 0.38 + float(index) * 0.08
				reflection.bottom_radius = reflection.top_radius
				reflection.height = 0.025
				reflection.radial_segments = 12
				mesh = reflection
			_:
				var ribbon := QuadMesh.new()
				ribbon.size = Vector2(0.16 + float(index % 2) * 0.08, 1.35 + float(index) * 0.12)
				mesh = ribbon
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(definition.event_color, 0.22)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = definition.event_color
		material.emission_energy_multiplier = 0.85
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if mesh is PrimitiveMesh:
			(mesh as PrimitiveMesh).material = material
		else:
			for surface_index: int in mesh.get_surface_count():
				mesh.surface_set_material(surface_index, material)
		visual.mesh = mesh
		var angle := TAU * float(index) / float(count)
		var radius := definition.danger_radius * (0.54 + float(index % 2) * 0.08)
		visual.position = Vector3(cos(angle) * radius, 0.45 + float(index % 3) * 0.42, sin(angle) * radius)
		visual.rotation.y = -angle
		if definition.event_rule == WorldMysteryDefinition.EventRule.APPROACH_SLOWLY:
			visual.position.y = 0.035 + float(index) * 0.012
		if definition.event_rule == WorldMysteryDefinition.EventRule.KEEP_WALKING:
			visual.rotation.y += PI * 0.5
		visual.set_meta(&"base_y", visual.position.y)
		_pulse_root.add_child(visual)
		_rule_visuals.append(visual)


func _get_recorded_event_layer(rule: int) -> AudioStream:
	match rule:
		WorldMysteryDefinition.EventRule.KEEP_WALKING:
			return RECORDED_WIND
		WorldMysteryDefinition.EventRule.CROUCH_AND_LISTEN:
			return RECORDED_CAVERN
		WorldMysteryDefinition.EventRule.APPROACH_SLOWLY:
			return RECORDED_ROOTS
		_:
			return RECORDED_UNCANNY_FOREST
