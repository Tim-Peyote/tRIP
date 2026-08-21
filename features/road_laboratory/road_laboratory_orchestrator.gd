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
	_session_active = true
	unlocked = false
	manifested = false
	ritual_position = _grounded(cairn_position)
	laboratory_position = Vector3.ZERO
	_cairn.global_position = ritual_position
	_cairn.set_available(true)
	_set_lab_active(false)
	_player.global_position = _grounded(start_position) + Vector3.UP * 0.18
	_player.rotation.y = PI
	ritual_state_changed.emit(unlocked, manifested)


func manifest_near_player(animate: bool = true) -> void:
	if not unlocked or manifested or _busy:
		return
	var forward := -_player.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	laboratory_position = _grounded(_player.global_position + forward * 4.2)
	_laboratory_root.global_position = laboratory_position
	_laboratory_root.rotation.y = _player.rotation.y
	if animate:
		_play_manifestation(true)
	else:
		manifested = true
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
		ritual_state_changed.emit(unlocked, manifested)
		autosave_requested.emit(&"laboratory_dismissed")


func to_save_data() -> Dictionary:
	return {
		"unlocked": unlocked,
		"manifested": manifested,
		"ritual_position": _vector_to_array(ritual_position),
		"laboratory_position": _vector_to_array(laboratory_position),
	}


func apply_save_data(data: Dictionary) -> void:
	_session_active = true
	unlocked = bool(data.get("unlocked", false))
	manifested = bool(data.get("manifested", false)) and unlocked
	ritual_position = _array_to_vector(data.get("ritual_position", []) as Array, ritual_position)
	laboratory_position = _array_to_vector(data.get("laboratory_position", []) as Array, laboratory_position)
	_cairn.global_position = ritual_position
	_cairn.set_available(not unlocked)
	_laboratory_root.global_position = laboratory_position
	_set_lab_active(manifested)
	ritual_state_changed.emit(unlocked, manifested)


func migrate_legacy_save() -> void:
	_session_active = true
	unlocked = true
	manifested = false
	_cairn.set_available(false)
	manifest_near_player(false)


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
	if appearing:
		manifested = true
		_set_lab_active(true)
		_laboratory_root.scale = Vector3(0.08, 1.8, 0.08)
	else:
		_set_interactions_enabled(false)
	var tween := create_tween().set_parallel(true)
	var target_scale := Vector3.ONE if appearing else Vector3(0.08, 1.8, 0.08)
	tween.tween_property(_laboratory_root, "scale", target_scale, 1.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT if appearing else Tween.EASE_IN)
	tween.tween_property(_metamorphosis_root, "rotation:y", _metamorphosis_root.rotation.y + TAU * 1.5, 1.35)
	tween.finished.connect(func() -> void:
		_busy = false
		_metamorphosis_root.visible = false
		if not appearing:
			manifested = false
			_set_lab_active(false)
		else:
			_laboratory_root.scale = Vector3.ONE
			_set_interactions_enabled(true)
		ritual_state_changed.emit(unlocked, manifested)
		metamorphosis_finished.emit()
		autosave_requested.emit(&"laboratory_manifested" if appearing else &"laboratory_dismissed")
	)


func _set_lab_active(value: bool) -> void:
	_laboratory_root.visible = value
	_laboratory_root.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	_set_interactions_enabled(value)
	for node: Node in _laboratory_root.find_children("*", "CollisionShape3D", true, false):
		(node as CollisionShape3D).set_deferred("disabled", not value)
	if _proximity_area != null:
		_proximity_area.set_deferred("monitoring", value and _session_active)


func _set_interactions_enabled(value: bool) -> void:
	for node: Node in _laboratory_root.find_children("*", "InteractableComponent", true, false):
		(node as InteractableComponent).enabled = value


func _build_portable_camp() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("5f3923")
	wood.roughness = 0.88
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color("273f35")
	cloth.roughness = 0.76
	for x: float in [-2.25, 2.25]:
		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.055
		pole_mesh.bottom_radius = 0.08
		pole_mesh.height = 2.45
		pole_mesh.radial_segments = 6
		pole.mesh = pole_mesh
		pole.material_override = wood
		pole.position = Vector3(x, 1.22, -2.45)
		_laboratory_root.add_child(pole)
	var tarp := MeshInstance3D.new()
	var tarp_mesh := PrismMesh.new()
	tarp_mesh.size = Vector3(4.8, 0.08, 2.7)
	tarp.mesh = tarp_mesh
	tarp.material_override = cloth
	tarp.position = Vector3(0, 2.35, -2.3)
	tarp.rotation_degrees = Vector3(0, 0, 4)
	_laboratory_root.add_child(tarp)
	for index: int in 9:
		var angle := TAU * float(index) / 9.0
		var stone := MeshInstance3D.new()
		var stone_mesh := BoxMesh.new()
		stone_mesh.size = Vector3(0.32, 0.2, 0.25)
		stone.mesh = stone_mesh
		stone.material_override = wood
		stone.position = Vector3(cos(angle) * 0.62, 0.12, sin(angle) * 0.62)
		stone.rotation.y = -angle
		_laboratory_root.add_child(stone)


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
	material.emission_energy_multiplier = 3.6
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


func _grounded(value: Vector3) -> Vector3:
	var result := value
	result.y = _terrain.get_height_at_global(value) + 0.03
	return result


func _vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _array_to_vector(data: Array, fallback: Vector3) -> Vector3:
	if data.size() != 3:
		return fallback
	return Vector3(float(data[0]), float(data[1]), float(data[2]))
