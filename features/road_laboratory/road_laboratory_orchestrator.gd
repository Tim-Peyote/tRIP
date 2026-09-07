class_name RoadLaboratoryOrchestrator
extends Node3D

signal ritual_state_changed(unlocked: bool, manifested: bool)
signal metamorphosis_started()
signal metamorphosis_finished()
signal autosave_requested(reason: StringName)
signal laboratory_entered(actor: Node)

const LAB_INPUT: StringName = &"road_laboratory"

var unlocked: bool = false
var manifested: bool = false
var ritual_position: Vector3
var laboratory_position: Vector3
var _player: FirstPersonController
var _terrain: ExpeditionTerrain
var _laboratory_root: Node3D
var _cairn: RitualCairn
var _metamorphosis_root: Node3D
var _busy: bool = false
var _proximity_area: Area3D
var _session_active: bool = false
var _metamorphosis_tween: Tween
var _dressing: PortableLaboratoryDressing


func get_laboratory_root() -> Node3D:
	return _laboratory_root


func setup_authored(player: FirstPersonController, terrain: ExpeditionTerrain, laboratory: Node3D) -> void:
	_player = player
	_terrain = terrain
	_laboratory_root = laboratory
	_proximity_area = laboratory.get_node("LaboratoryProximity") as Area3D
	_proximity_area.body_entered.connect(func(body: Node3D) -> void: laboratory_entered.emit(body))
	_metamorphosis_root = (load("res://features/road_laboratory/laboratory_metamorphosis.tscn") as PackedScene).instantiate() as Node3D
	add_child(_metamorphosis_root)
	_cairn = RitualCairn.new()
	_cairn.name = "FirstRitualCairn"
	add_child(_cairn)
	_cairn.ritual_completed.connect(_on_first_ritual_completed)
	_cairn.set_available(false)
	_set_lab_active(false)


func setup(player: FirstPersonController, terrain: ExpeditionTerrain, portable_nodes: Array[Node]) -> void:
	_player = player
	_terrain = terrain
	_laboratory_root = Node3D.new()
	_laboratory_root.name = "PortableLaboratory"
	add_child(_laboratory_root)
	for portable_node: Node in portable_nodes:
		if is_instance_valid(portable_node):
			portable_node.reparent(_laboratory_root, true)
	_build_portable_camp()
	_build_proximity_area()
	_build_metamorphosis_vfx()
	_cairn = RitualCairn.new()
	_cairn.name = "FirstRitualCairn"
	_cairn.ritual_completed.connect(_on_first_ritual_completed)
	add_child(_cairn)
	set_process_unhandled_input(true)
	# Scene-level test fixtures still exercise the legacy workbench directly.
	# A real session calls initialize_new_run/apply_save_data and owns visibility.
	_cairn.set_available(false)
	_set_lab_active(true)


func initialize_new_run(start_position: Vector3, cairn_position: Vector3) -> void:
	_terrain.clear_laboratory_site()
	_session_active = true
	unlocked = false
	manifested = false
	ritual_position = _grounded(cairn_position)
	laboratory_position = Vector3.ZERO
	_cairn.global_position = ritual_position
	_cairn.set_available(true)
	_set_lab_active(false)
	_player.global_position = _grounded(start_position) + Vector3.UP * 0.06
	_player.velocity = Vector3.ZERO
	_player.apply_floor_snap()
	_player.rotation.y = PI
	ritual_state_changed.emit(unlocked, manifested)


func manifest_near_player(animate: bool = true) -> void:
	if not unlocked or manifested or _busy:
		return
	var forward := -_player.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	laboratory_position = _find_camp_position(_player.global_position, forward)
	laboratory_position = _terrain.prepare_laboratory_site(laboratory_position)
	_laboratory_root.global_position = laboratory_position
	_laboratory_root.rotation.y = _player.rotation.y
	if animate:
		_play_manifestation(true)
	else:
		manifested = true
		_laboratory_root.scale = Vector3.ONE
		_set_lab_active(true)
		ritual_state_changed.emit(unlocked, manifested)
		autosave_requested.emit(&"laboratory_manifested")


func dismiss(animate: bool = true) -> void:
	if not manifested or _busy:
		return
	if animate:
		_play_manifestation(false)
	else:
		manifested = false
		_set_lab_active(false)
		_laboratory_root.scale = Vector3.ONE
		ritual_state_changed.emit(unlocked, manifested)
		autosave_requested.emit(&"laboratory_dismissed")


func to_save_data() -> Dictionary:
	return {
		"unlocked": unlocked,
		"manifested": manifested,
		"ritual_position": _vector_to_array(ritual_position),
		"laboratory_position": _vector_to_array(laboratory_position),
		"laboratory_yaw": _laboratory_root.rotation.y,
	}


func apply_save_data(data: Dictionary) -> void:
	_session_active = true
	unlocked = bool(data.get("unlocked", false))
	manifested = bool(data.get("manifested", false)) and unlocked
	ritual_position = _array_to_vector(data.get("ritual_position", []) as Array, ritual_position)
	laboratory_position = _array_to_vector(data.get("laboratory_position", []) as Array, laboratory_position)
	if manifested:
		laboratory_position = _terrain.prepare_laboratory_site(laboratory_position)
	_cairn.global_position = ritual_position
	_cairn.set_available(not unlocked)
	_laboratory_root.global_position = laboratory_position
	_laboratory_root.rotation.y = float(data.get("laboratory_yaw", _player.rotation.y))
	_set_lab_active(manifested)
	ritual_state_changed.emit(unlocked, manifested)


func migrate_legacy_save() -> void:
	_session_active = true
	unlocked = true
	manifested = false
	_cairn.set_available(false)
	manifest_near_player(false)


func get_hazard_protection_at(world_position: Vector3) -> float:
	if not manifested or not is_instance_valid(_laboratory_root):
		return 0.0
	var distance := world_position.distance_to(_laboratory_root.global_position + Vector3(0.0, 0.0, -1.2))
	return 1.0 - smoothstep(3.4, 5.4, distance)


func is_metamorphosing() -> bool:
	return _busy


func developer_unlock() -> void:
	if unlocked:
		return
	unlocked = true
	_cairn.set_available(false)
	ritual_state_changed.emit(unlocked, manifested)


func developer_toggle(animate: bool = true) -> bool:
	if _busy:
		return false
	developer_unlock()
	if manifested:
		dismiss(animate)
	else:
		manifest_near_player(animate)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(LAB_INPUT) and unlocked and not _busy:
		if manifested:
			dismiss()
		else:
			manifest_near_player()
		get_viewport().set_input_as_handled()


func _on_first_ritual_completed(_actor: Node) -> void:
	unlocked = true
	manifest_near_player(true)
	autosave_requested.emit(&"laboratory_ritual_completed")


func _play_manifestation(appearing: bool) -> void:
	_busy = true
	metamorphosis_started.emit()
	_metamorphosis_root.global_position = laboratory_position + Vector3.UP * 0.12
	_metamorphosis_root.visible = true
	_metamorphosis_root.scale = Vector3.ONE * (0.32 if appearing else 1.0)
	if appearing:
		manifested = true
		_laboratory_root.visible = true
		_laboratory_root.process_mode = Node.PROCESS_MODE_INHERIT
		_set_interactions_enabled(false)
		_set_collisions_enabled(false)
		_laboratory_root.scale = Vector3(0.08, 1.8, 0.08)
	else:
		_set_interactions_enabled(false)
		_set_collisions_enabled(false)
		_proximity_area.set_deferred("monitoring", false)
	_metamorphosis_tween = create_tween().set_parallel(true)
	var target_scale := Vector3.ONE if appearing else Vector3(0.08, 1.8, 0.08)
	_metamorphosis_tween.tween_property(_laboratory_root, "scale", target_scale, 1.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT if appearing else Tween.EASE_IN)
	_metamorphosis_tween.tween_property(_metamorphosis_root, "scale", Vector3.ONE * (1.18 if appearing else 0.22), 1.35).set_trans(Tween.TRANS_SINE)
	_metamorphosis_tween.tween_property(_metamorphosis_root, "rotation:y", _metamorphosis_root.rotation.y + TAU * 1.5, 1.35)
	_metamorphosis_tween.finished.connect(func() -> void:
		_busy = false
		_metamorphosis_root.visible = false
		_metamorphosis_root.scale = Vector3.ONE
		if not appearing:
			manifested = false
			_set_lab_active(false)
			_laboratory_root.scale = Vector3.ONE
		else:
			_laboratory_root.scale = Vector3.ONE
			_set_lab_active(true)
		ritual_state_changed.emit(unlocked, manifested)
		metamorphosis_finished.emit()
		autosave_requested.emit(&"laboratory_manifested" if appearing else &"laboratory_dismissed")
	)


func _set_lab_active(value: bool) -> void:
	_laboratory_root.visible = value
	_laboratory_root.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	_set_interactions_enabled(value)
	_set_collisions_enabled(value)
	if _proximity_area != null:
		_proximity_area.set_deferred("monitoring", value and _session_active)


func _set_collisions_enabled(value: bool) -> void:
	for node: Node in _laboratory_root.find_children("*", "CollisionShape3D", true, false):
		(node as CollisionShape3D).set_deferred("disabled", not value)


func _set_interactions_enabled(value: bool) -> void:
	for node: Node in _laboratory_root.find_children("*", "InteractableComponent", true, false):
		(node as InteractableComponent).enabled = value


func _build_portable_camp() -> void:
	_dressing = PortableLaboratoryDressing.new()
	_dressing.build(_laboratory_root)


func _build_proximity_area() -> void:
	var area := Area3D.new()
	area.name = "LaboratoryProximity"
	area.collision_layer = 0
	area.collision_mask = 2
	area.body_entered.connect(func(body: Node3D) -> void: laboratory_entered.emit(body))
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.8
	shape.shape = sphere
	shape.position = Vector3(0, 1.2, -1.5)
	area.add_child(shape)
	_laboratory_root.add_child(area)
	_proximity_area = area
	area.monitoring = false


func _build_metamorphosis_vfx() -> void:
	_metamorphosis_root = Node3D.new()
	_metamorphosis_root.name = "LaboratoryMetamorphosis"
	_metamorphosis_root.visible = false
	add_child(_metamorphosis_root)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.28, 0.92, 0.62, 0.58)
	material.emission_enabled = true
	material.emission = Color(0.17, 0.82, 0.66)
	material.emission_energy_multiplier = 1.4
	for index: int in 3:
		var ring := MeshInstance3D.new()
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 1.8 + float(index) * 0.72
		ring_mesh.outer_radius = ring_mesh.inner_radius + 0.055
		ring_mesh.rings = 24
		ring_mesh.ring_segments = 5
		ring.mesh = ring_mesh
		ring.material_override = material
		ring.position.y = float(index) * 0.42
		ring.rotation.x = 0.08 * float(index - 1)
		_metamorphosis_root.add_child(ring)
	var particles := GPUParticles3D.new()
	particles.name = "MetamorphosisSpores"
	particles.amount = 96
	particles.lifetime = 1.8
	particles.preprocess = 1.8
	particles.randomness = 0.72
	particles.visibility_aabb = AABB(Vector3(-5, -1, -5), Vector3(10, 6, 10))
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 3.8
	process_material.direction = Vector3(0, 1, 0)
	process_material.spread = 38.0
	process_material.initial_velocity_min = 0.35
	process_material.initial_velocity_max = 1.4
	process_material.gravity = Vector3(0, 0.16, 0)
	process_material.scale_min = 0.35
	process_material.scale_max = 1.1
	particles.process_material = process_material
	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.045)
	var particle_surface := StandardMaterial3D.new()
	particle_surface.albedo_color = Color(0.28, 0.92, 0.62, 0.7)
	particle_surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_surface.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particle_surface.emission_enabled = true
	particle_surface.emission = Color(0.17, 0.82, 0.66)
	particle_surface.emission_energy_multiplier = 0.75
	quad.material = particle_surface
	particles.draw_pass_1 = quad
	_metamorphosis_root.add_child(particles)


func _grounded(value: Vector3) -> Vector3:
	var result := value
	result.y = _terrain.get_height_at_global(value) + 0.03
	return result


func _find_camp_position(origin: Vector3, forward: Vector3) -> Vector3:
	# The camp spans several metres. Evaluate a few nearby footprints instead
	# of balancing the whole laboratory on the height at a single point.
	var right := Vector3(forward.z, 0.0, -forward.x).normalized()
	var best := _grounded(origin + forward * 4.2)
	var best_score := INF
	for distance: float in [3.8, 4.6, 5.4]:
		for lateral: float in [-2.0, 0.0, 2.0]:
			var candidate := origin + forward * distance + right * lateral
			var minimum_height := INF
			var maximum_height := -INF
			for offset: Vector2 in [Vector2.ZERO, Vector2(-3.2, -2.0), Vector2(3.2, -2.0), Vector2(-3.2, 1.4), Vector2(3.2, 1.4)]:
				var sample := candidate + right * offset.x + forward * offset.y
				var height := _terrain.get_height_at_global(sample)
				minimum_height = minf(minimum_height, height)
				maximum_height = maxf(maximum_height, height)
			var relief := maximum_height - minimum_height
			var score := relief + absf(lateral) * 0.025 + absf(distance - 4.6) * 0.018
			if score < best_score:
				best_score = score
				best = _grounded(candidate)
	return best


func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _array_to_vector(data: Array, fallback: Vector3) -> Vector3:
	if data.size() != 3:
		return fallback
	return Vector3(float(data[0]), float(data[1]), float(data[2]))
