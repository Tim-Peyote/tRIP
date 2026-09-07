class_name BiomeCreatureActor
extends CharacterBody3D

signal state_changed(state: int)

enum State { IDLE, FORAGE, WANDER, NOTICE, FLEE, STALK, OBSERVE }

var definition: CreatureArchetypeDefinition
var state: State = State.IDLE
var _player: Node3D
var _terrain: ExpeditionTerrain
var _rng := RandomNumberGenerator.new()
var _heading := Vector3.FORWARD
var _state_time: float = 0.0
var _gait_phase: float = 0.0
var _visual_root: Node3D
var _body: Node3D
var _head: Node3D
var _limbs: Array[Node3D] = []
var _animation_player: AnimationPlayer
var _active_animation: StringName
var _home: Vector3
var _awareness_time: float = 0.0


func setup(value: CreatureArchetypeDefinition, player: Node3D, terrain: ExpeditionTerrain, spawn_seed: int) -> void:
	definition = value
	_player = player
	_terrain = terrain
	_rng.seed = spawn_seed
	name = "Creature_%s" % definition.id
	collision_layer = 1 << 3
	collision_mask = 1
	_build_character()
	_home = global_position
	_choose_state(State.FORAGE)
	set_physics_process(true)


func get_character_sheet_summary() -> String:
	return "%s · %s · %s" % [definition.display_name, definition.silhouette_notes, ", ".join(definition.animation_states)]


func _physics_process(delta: float) -> void:
	if definition == null or not is_instance_valid(_player):
		return
	_state_time -= delta
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	_awareness_time = _awareness_time + delta if distance <= definition.awareness_distance else maxf(_awareness_time - delta * 2.0, 0.0)
	_update_awareness(distance, to_player)
	var desired_velocity := Vector3.ZERO
	match state:
		State.FLEE:
			desired_velocity = -to_player.normalized() * definition.move_speed * 1.35
		State.STALK:
			var stand_off := maxf(definition.flee_distance, 9.0)
			desired_velocity = to_player.normalized() * definition.move_speed * (0.62 if distance > stand_off else 0.0)
		State.WANDER, State.FORAGE:
			desired_velocity = _heading * definition.move_speed * (0.42 if state == State.FORAGE else 0.68)
		State.OBSERVE:
			_heading = to_player.normalized() if distance > 0.1 else _heading
	if _state_time <= 0.0:
		_choose_next_state()
	velocity.x = move_toward(velocity.x, desired_velocity.x, delta * 4.5)
	velocity.z = move_toward(velocity.z, desired_velocity.z, delta * 4.5)
	if definition.body_plan == CreatureArchetypeDefinition.BodyPlan.BIRD:
		velocity.y = sin(Time.get_ticks_msec() * 0.0017 + float(_rng.seed % 17)) * 0.22
	else:
		velocity.y -= 18.0 * delta
	move_and_slide()
	if definition.body_plan != CreatureArchetypeDefinition.BodyPlan.BIRD and is_instance_valid(_terrain):
		var ground := _terrain.get_height_at_global(global_position)
		if global_position.y < ground + 0.05:
			global_position.y = ground + 0.05
	if Vector2(velocity.x, velocity.z).length() > 0.08:
		var facing := Vector3(velocity.x, 0.0, velocity.z).normalized()
		rotation.y = lerp_angle(rotation.y, atan2(facing.x, facing.z), delta * 4.0)
	_animate_character(delta, Vector2(velocity.x, velocity.z).length())


func _update_awareness(distance: float, to_player: Vector3) -> void:
	if distance > definition.awareness_distance:
		return
	match definition.temperament:
		CreatureArchetypeDefinition.Temperament.SHY:
			if distance < definition.flee_distance: _choose_state(State.FLEE)
		CreatureArchetypeDefinition.Temperament.PREDATORY:
			# A predator first reveals itself and watches. It only closes distance
			# after sustained proximity, instead of homing in from the chunk edge.
			var commitment_distance := minf(definition.flee_distance * 1.55, 16.0)
			if distance <= commitment_distance and _awareness_time >= 3.0:
				if state != State.STALK: _choose_state(State.STALK)
			elif state not in [State.OBSERVE, State.STALK]:
				_choose_state(State.OBSERVE)
		CreatureArchetypeDefinition.Temperament.TERRITORIAL:
			_choose_state(State.OBSERVE if distance > definition.flee_distance or _awareness_time < 2.0 else State.STALK)
		CreatureArchetypeDefinition.Temperament.CURIOUS, CreatureArchetypeDefinition.Temperament.MYTHIC:
			_choose_state(State.OBSERVE)
		_:
			if state != State.NOTICE: _choose_state(State.NOTICE)
	if to_player.length_squared() > 0.01 and state in [State.NOTICE, State.OBSERVE, State.STALK]:
		_heading = to_player.normalized()


func _choose_next_state() -> void:
	if global_position.distance_to(_home) > 22.0:
		_heading = (_home - global_position).normalized()
		_choose_state(State.WANDER)
		return
	_heading = Vector3(cos(_rng.randf_range(0.0, TAU)), 0.0, sin(_rng.randf_range(0.0, TAU))).normalized()
	_choose_state(State.FORAGE if _rng.randf() < 0.62 else State.WANDER)


func _choose_state(value: State) -> void:
	if state == value and _state_time > 0.2:
		return
	state = value
	_state_time = _rng.randf_range(2.0, 6.0)
	if value in [State.NOTICE, State.OBSERVE]: _state_time = _rng.randf_range(1.2, 3.0)
	if value == State.FLEE: _state_time = _rng.randf_range(3.0, 5.5)
	state_changed.emit(state)


func _build_character() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "AnimatedSilhouette"
	add_child(_visual_root)
	var scale_factor := definition.visual_scale
	if definition.visual_scene != null:
		_build_rigged_character()
	else:
		_build_procedural_character()
	_visual_root.scale = Vector3.ONE * scale_factor
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = definition.collision_radius * scale_factor
	shape.height = maxf(definition.collision_height * scale_factor, shape.radius * 2.0)
	collision.shape = shape
	collision.position.y = shape.height * 0.5
	add_child(collision)


func _build_rigged_character() -> void:
	var selected_scene := definition.visual_scene
	if not definition.visual_scene_variants.is_empty():
		var variant_roll := absi(int(_rng.seed)) % (definition.visual_scene_variants.size() + 1)
		if variant_roll > 0:
			selected_scene = definition.visual_scene_variants[variant_roll - 1]
	var imported := selected_scene.instantiate() as Node3D
	if imported == null:
		_build_procedural_character()
		return
	imported.name = "RiggedAnimal"
	imported.scale = Vector3.ONE * definition.visual_scene_scale
	imported.rotation_degrees.y = definition.visual_scene_yaw
	_visual_root.add_child(imported)
	_animation_player = imported.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _animation_player != null:
		for animation_name in _animation_player.get_animation_list():
			if animation_name != &"RESET":
				_animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	for mesh: Node in imported.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _build_procedural_character() -> void:
	var material := _material(definition.body_color)
	var accent := _material(definition.accent_color, definition.temperament == CreatureArchetypeDefinition.Temperament.MYTHIC)
	match definition.body_plan:
		CreatureArchetypeDefinition.BodyPlan.BIRD:
			_body = _part(_ellipsoid(Vector3(0.75, 0.34, 0.38)), material, Vector3(0, 1.0, 0))
			_head = _part(_ellipsoid(Vector3(0.3, 0.3, 0.32)), accent, Vector3(0, 1.14, 0.54))
			_limbs.append(_part(_box(Vector3(1.35, 0.08, 0.48)), material, Vector3(-0.68, 1.02, 0), Vector3(0, 0, 0.12)))
			_limbs.append(_part(_box(Vector3(1.35, 0.08, 0.48)), material, Vector3(0.68, 1.02, 0), Vector3(0, 0, -0.12)))
		CreatureArchetypeDefinition.BodyPlan.BEAR:
			_build_quadruped(material, accent, Vector3(1.65, 0.9, 0.86), 0.78, 0.95)
		CreatureArchetypeDefinition.BodyPlan.SMALL_MAMMAL:
			_build_quadruped(material, accent, Vector3(0.72, 0.38, 0.34), 0.34, 0.42)
		CreatureArchetypeDefinition.BodyPlan.PREDATOR:
			_build_quadruped(material, accent, Vector3(1.28, 0.58, 0.52), 0.52, 0.68)
		_:
			_build_quadruped(material, accent, Vector3(1.38, 0.7, 0.58), 0.58, 0.92)


func _build_quadruped(material: Material, accent: Material, body_size: Vector3, leg_length: float, head_height: float) -> void:
	_body = _part(_ellipsoid(body_size), material, Vector3(0, leg_length + body_size.y * 0.45, 0))
	_head = _part(_ellipsoid(Vector3(body_size.y * 0.62, body_size.y * 0.58, body_size.y * 0.72)), accent, Vector3(0, leg_length + head_height, body_size.z * 0.9))
	for x_sign: float in [-1.0, 1.0]:
		for z_sign: float in [-1.0, 1.0]:
			var leg := _part(_cylinder(body_size.y * 0.1, leg_length), material, Vector3(x_sign * body_size.x * 0.3, leg_length * 0.5, z_sign * body_size.z * 0.48))
			_limbs.append(leg)
	if definition.body_plan == CreatureArchetypeDefinition.BodyPlan.UNGULATE:
		for side: float in [-1.0, 1.0]:
			var horn := _part(_cylinder(0.035, body_size.y * 0.85), accent, Vector3(side * body_size.y * 0.24, leg_length + head_height + body_size.y * 0.5, body_size.z * 0.9), Vector3(0.0, 0.0, side * 0.28))
			_limbs.append(horn)


func _animate_character(delta: float, planar_speed: float) -> void:
	if _animation_player != null:
		_animation_player.speed_scale = clampf(planar_speed / maxf(definition.move_speed * 0.55, 0.1), 0.72, 1.45) if state in [State.WANDER, State.FLEE, State.STALK] else 1.0
		_play_state_animation()
		return
	_gait_phase += delta * (2.0 + planar_speed * 2.8)
	var moving := clampf(planar_speed / maxf(definition.move_speed, 0.1), 0.0, 1.5)
	if _body != null:
		_body.rotation.z = sin(_gait_phase) * 0.025 * moving
		_body.position.y += sin(_gait_phase * 2.0) * 0.0015 * moving
	if _head != null:
		_head.rotation.x = (-0.34 if state == State.FORAGE else 0.0) + sin(_gait_phase * 0.5) * 0.035
	for index: int in _limbs.size():
		var limb := _limbs[index]
		if definition.body_plan == CreatureArchetypeDefinition.BodyPlan.BIRD:
			limb.rotation.z = (0.28 if index == 0 else -0.28) + sin(_gait_phase * 2.2) * (0.55 if index == 0 else -0.55)
		else:
			limb.rotation.x = sin(_gait_phase + (PI if index % 2 == 0 else 0.0)) * 0.45 * moving


func _play_state_animation() -> void:
	if _animation_player == null:
		return
	var requested := definition.idle_animation
	match state:
		State.FORAGE: requested = definition.forage_animation
		State.WANDER, State.STALK: requested = definition.walk_animation
		State.FLEE: requested = definition.run_animation
		State.NOTICE, State.OBSERVE: requested = definition.notice_animation
	var resolved := _resolve_animation_name(requested)
	if resolved == &"" or resolved == _active_animation:
		return
	_active_animation = resolved
	_animation_player.play(resolved, 0.22)


func _resolve_animation_name(requested: StringName) -> StringName:
	if _animation_player.has_animation(requested):
		return requested
	var suffix := "|%s" % String(requested)
	for animation_name: StringName in _animation_player.get_animation_list():
		if String(animation_name).ends_with(suffix):
			return animation_name
	return &""


func _part(mesh: Mesh, material: Material, position_value: Vector3, rotation_value: Vector3 = Vector3.ZERO) -> Node3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position_value
	instance.rotation = rotation_value
	_visual_root.add_child(instance)
	return instance


func _ellipsoid(size: Vector3) -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = maxf(size.x, size.z)
	mesh.height = size.y * 2.0
	mesh.radial_segments = 8
	mesh.rings = 5
	return mesh


func _box(size: Vector3) -> Mesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _cylinder(radius: float, height: float) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.75
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	return mesh


func _material(color: Color, emissive: bool = false) -> Material:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.75
	return material
