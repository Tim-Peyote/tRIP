class_name FirstPersonController
extends CharacterBody3D

signal step_taken(origin: Vector3, intensity: float)
signal inventory_requested
signal journal_requested
signal tool_state_changed(display_name: String, is_equipped: bool)
signal distraction_created(projectile: DistractionProjectile)
signal distraction_count_changed(remaining: int)
signal landed(impact_speed: float)
signal jumped

@export_category("Look")
@export_range(0.01, 1.0, 0.01) var mouse_sensitivity: float = 0.12
@export_range(50.0, 110.0, 1.0, "suffix:°") var field_of_view: float = 75.0
@export_range(45.0, 89.0, 1.0, "suffix:°") var vertical_look_limit: float = 85.0

@export_category("Movement")
@export_range(0.1, 12.0, 0.1, "suffix:m/s") var walk_speed: float = 3.4
@export_range(0.1, 16.0, 0.1, "suffix:m/s") var sprint_speed: float = 5.6
@export_range(0.1, 8.0, 0.1, "suffix:m/s") var crouch_speed: float = 1.8
@export_range(1.0, 30.0, 0.5) var ground_acceleration: float = 16.0
@export_range(1.0, 20.0, 0.5) var air_acceleration: float = 4.0
@export_range(1.0, 30.0, 0.5) var ground_deceleration: float = 20.0
@export_range(1.0, 10.0, 0.1, "suffix:m/s") var jump_velocity: float = 4.6
@export_range(0.0, 0.3, 0.01, "suffix:s") var coyote_time: float = 0.12
@export_range(0.0, 0.3, 0.01, "suffix:s") var jump_buffer_time: float = 0.14
@export_range(0.0, 8.0, 0.1) var rigid_body_push_force: float = 1.8
@export_range(0.0, 0.5, 0.01, "suffix:m") var step_height: float = 0.28

@export_category("Camera Feel")
@export_range(0.0, 0.08, 0.001) var head_bob_amount: float = 0.018
@export_range(0.0, 16.0, 0.1) var head_bob_frequency: float = 8.5
@export_range(0.0, 0.08, 0.001) var viewmodel_bob_amount: float = 0.028
@export_range(0.0, 0.01, 0.0005) var viewmodel_look_inertia: float = 0.0035

@onready var camera_rig: Node3D = %CameraRig
@onready var camera: Camera3D = %Camera3D
@onready var viewmodel: Node3D = %ViewModel
@onready var collision_shape: CollisionShape3D = %CollisionShape3D
@onready var crouch_clearance: RayCast3D = %CrouchClearance
@onready var interactor: InteractionOrchestrator = %InteractionOrchestrator
@onready var inventory: InventoryComponent = %InventoryComponent
@onready var noise_emitter: NoiseEmitterComponent = %NoiseEmitterComponent
@onready var toolbelt: ToolbeltComponent = %ToolbeltComponent
@onready var knife_viewmodel: Node3D = %KnifeViewModel
@onready var vial_viewmodel: Node3D = %VialViewModel
@onready var distraction_thrower: DistractionThrowerComponent = %DistractionThrowerComponent
@onready var avatar_animator: PlayerAvatarAnimator = %AvatarAnimator

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var _look_pitch: float = 0.0
var _bob_time: float = 0.0
var _bob_weight: float = 0.0
var _step_distance: float = 0.0
var _last_position: Vector3
var _is_crouched: bool = false
var _viewmodel_rest_position: Vector3
var _viewmodel_look_offset: Vector2 = Vector2.ZERO
var _spore_vision_active: bool = false
var _spore_resistance: float = 0.0
var _crimson_drive_amount: float = 0.0
var _consumption_tween: Tween
var _coyote_remaining: float = 0.0
var _jump_buffer_remaining: float = 0.0
var _landing_offset: float = 0.0
var _landing_velocity: float = 0.0
var _camera_roll: float = 0.0
var _previously_grounded: bool = false
var _is_sprinting: bool = false
var _wish_direction: Vector3 = Vector3.ZERO
var _gameplay_input_override: bool = false
var _pre_slide_planar_velocity: Vector3 = Vector3.ZERO
var _surface_wetness: float = 0.0
var _weather_wind_strength: float = 0.0

const STANDING_CAMERA_HEIGHT: float = 1.58
const CROUCHED_CAMERA_HEIGHT: float = 1.05
const STANDING_BODY_HEIGHT: float = 1.72
const CROUCHED_BODY_HEIGHT: float = 1.15


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.fov = float(SettingsService.get_value(&"video", &"fov", field_of_view))
	_look_pitch = camera_rig.rotation.x
	interactor.actor = self
	toolbelt.setup_viewmodels({
		&"tool.field_knife": knife_viewmodel,
		&"tool.spore_vial": vial_viewmodel,
	})
	toolbelt.tool_changed.connect(_on_tool_changed)
	distraction_thrower.projectile_created.connect(distraction_created.emit)
	distraction_thrower.count_changed.connect(distraction_count_changed.emit)
	_last_position = global_position
	_viewmodel_rest_position = viewmodel.position
	floor_snap_length = 0.32
	floor_max_angle = deg_to_rad(48.0)
	floor_stop_on_slope = true
	floor_constant_speed = false
	safe_margin = 0.035
	_previously_grounded = is_on_floor()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"inventory"):
		inventory_requested.emit()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"journal"):
		journal_requested.emit()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"quick_use"):
		inventory.use_first_consumable()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"quick_tool"):
		toolbelt.cycle_active_tool()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"throw_distraction"):
		distraction_thrower.throw(camera.global_position + -camera.global_basis.z * 0.35, -camera.global_basis.z)
		get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"jump"):
		_jump_buffer_remaining = jump_buffer_time
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if interactor != null and interactor.is_rotating_held_body():
			return
		var motion := event as InputEventMouseMotion
		_viewmodel_look_offset += Vector2(motion.relative.x, motion.relative.y) * viewmodel_look_inertia
		_viewmodel_look_offset = _viewmodel_look_offset.limit_length(0.075)
		rotate_y(deg_to_rad(-motion.relative.x * mouse_sensitivity))
		_look_pitch = clampf(
			_look_pitch - deg_to_rad(motion.relative.y * mouse_sensitivity),
			deg_to_rad(-vertical_look_limit),
			deg_to_rad(vertical_look_limit)
		)
		camera_rig.rotation.x = _look_pitch


func _physics_process(delta: float) -> void:
	_coyote_remaining = coyote_time if is_on_floor() else maxf(_coyote_remaining - delta, 0.0)
	_jump_buffer_remaining = maxf(_jump_buffer_remaining - delta, 0.0)
	if _accepts_gameplay_input() and Input.is_action_just_pressed(&"jump"):
		_jump_buffer_remaining = jump_buffer_time
	if _accepts_gameplay_input():
		_update_gamepad_look(delta)
		_update_stance(delta)
	if not _accepts_gameplay_input():
		velocity.x = move_toward(velocity.x, 0.0, ground_acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_acceleration * delta)
		_apply_gravity(delta)
		move_and_slide()
		_update_viewmodel(delta, 0.0)
		return

	var input_vector := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back", 0.15)
	var input_amount := minf(input_vector.length(), 1.0)
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var world_direction := global_basis * local_direction
	if world_direction.length_squared() > 0.0001:
		world_direction = world_direction.normalized()
	if is_on_floor():
		world_direction = world_direction.slide(get_floor_normal()).normalized()
	_wish_direction = world_direction
	var target_speed := _get_target_speed()
	var has_input := input_amount > 0.01
	var wet_traction := lerpf(1.0, 0.72, _surface_wetness)
	var acceleration := ((ground_acceleration if has_input else ground_deceleration) * wet_traction) if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, world_direction.x * target_speed * input_amount, acceleration * delta)
	velocity.z = move_toward(velocity.z, world_direction.z * target_speed * input_amount, acceleration * delta)
	_try_jump()
	var falling_speed := -velocity.y
	_apply_gravity(delta)
	_try_step_up(delta)
	_pre_slide_planar_velocity = Vector3(velocity.x, 0.0, velocity.z)
	move_and_slide()
	_push_rigid_bodies()
	if not _previously_grounded and is_on_floor() and falling_speed > 2.0:
		_on_landed(falling_speed)
	_previously_grounded = is_on_floor()
	var movement_strength := clampf(get_planar_speed() / maxf(target_speed, 0.01), 0.0, 1.0)
	_update_camera_feel(delta, movement_strength)
	_update_viewmodel(delta, movement_strength)
	_update_steps()


func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_gameplay_input_override_for_testing(value: bool) -> void:
	_gameplay_input_override = value


func get_stealth_exposure() -> float:
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var movement_exposure := remap(clampf(planar_speed, 0.0, sprint_speed), 0.0, sprint_speed, 0.72, 1.35)
	var stance_exposure := 0.48 if _is_crouched else 1.0
	var perception_price := 1.28 if _spore_vision_active else 1.0
	var crimson_price := lerpf(1.0, 1.45, _crimson_drive_amount)
	var quieting := lerpf(1.0, 0.72, _spore_resistance)
	return clampf(movement_exposure * stance_exposure * perception_price * crimson_price * quieting, 0.25, 1.9)


func get_planar_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func is_crouched() -> bool:
	return _is_crouched


func is_grounded() -> bool:
	return is_on_floor()


func is_sprinting() -> bool:
	return _is_sprinting


func _accepts_gameplay_input() -> bool:
	return _gameplay_input_override or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func set_spore_vision_active(value: bool) -> void:
	_spore_vision_active = value


func set_spore_resistance(value: float) -> void:
	_spore_resistance = clampf(value, 0.0, 1.0)


func set_crimson_drive(value: float) -> void:
	_crimson_drive_amount = clampf(value, 0.0, 1.0)


func set_weather_modifiers(surface_wetness: float, wind_strength: float) -> void:
	_surface_wetness = clampf(surface_wetness, 0.0, 1.0)
	_weather_wind_strength = maxf(wind_strength, 0.0)


func play_consumption_animation(_effect_ids: Array[StringName], _display_name: String) -> void:
	if _consumption_tween != null and _consumption_tween.is_valid():
		_consumption_tween.kill()
	var resting_position := vial_viewmodel.position
	var resting_rotation := vial_viewmodel.rotation
	if avatar_animator != null:
		avatar_animator.play_work_action()
	vial_viewmodel.visible = true
	_consumption_tween = create_tween()
	_consumption_tween.set_trans(Tween.TRANS_SINE)
	_consumption_tween.set_ease(Tween.EASE_IN_OUT)
	_consumption_tween.set_parallel(true)
	_consumption_tween.tween_property(vial_viewmodel, "position", Vector3(0.11, -0.035, -0.34), 0.38)
	_consumption_tween.tween_property(vial_viewmodel, "rotation", Vector3(-1.42, 0.18, -0.18), 0.38)
	_consumption_tween.set_parallel(false)
	_consumption_tween.tween_interval(0.18)
	_consumption_tween.set_parallel(true)
	_consumption_tween.tween_property(vial_viewmodel, "position", resting_position, 0.32)
	_consumption_tween.tween_property(vial_viewmodel, "rotation", resting_rotation, 0.32)
	_consumption_tween.set_parallel(false)
	_consumption_tween.tween_callback(func() -> void:
		vial_viewmodel.visible = toolbelt.is_equipped and toolbelt.active_tool_id == &"tool.spore_vial"
	)


func _update_gamepad_look(delta: float) -> void:
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if look.length_squared() < 0.001:
		return
	var speed := 2.35
	rotate_y(-look.x * speed * delta)
	_look_pitch = clampf(
		_look_pitch - look.y * speed * delta,
		deg_to_rad(-vertical_look_limit),
		deg_to_rad(vertical_look_limit)
	)
	camera_rig.rotation.x = _look_pitch


func _get_target_speed() -> float:
	var drive_multiplier := lerpf(1.0, 1.22, _crimson_drive_amount)
	_is_sprinting = false
	if _is_crouched:
		return crouch_speed * drive_multiplier
	var forward_intent := -_wish_direction.dot(global_basis.z)
	if Input.is_action_pressed(&"sprint") and forward_intent > 0.35:
		_is_sprinting = true
		return sprint_speed * drive_multiplier
	return walk_speed * drive_multiplier


func _update_stance(delta: float) -> void:
	var wants_crouch := Input.is_action_pressed(&"crouch")
	if not wants_crouch and _is_crouched:
		crouch_clearance.force_raycast_update()
		if crouch_clearance.is_colliding():
			wants_crouch = true
	_is_crouched = wants_crouch
	var target_camera_height := CROUCHED_CAMERA_HEIGHT if _is_crouched else STANDING_CAMERA_HEIGHT
	var target_body_height := CROUCHED_BODY_HEIGHT if _is_crouched else STANDING_BODY_HEIGHT
	camera_rig.position.y = move_toward(camera_rig.position.y, target_camera_height, delta * 4.0)
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule != null:
		capsule.height = move_toward(capsule.height, target_body_height, delta * 4.0)
		collision_shape.position.y = capsule.height * 0.5


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.2


func _try_jump() -> void:
	if _jump_buffer_remaining <= 0.0 or _coyote_remaining <= 0.0 or _is_crouched:
		return
	velocity.y = jump_velocity
	_jump_buffer_remaining = 0.0
	_coyote_remaining = 0.0
	floor_snap_length = 0.0
	jumped.emit()
	call_deferred("_restore_floor_snap")


func _restore_floor_snap() -> void:
	floor_snap_length = 0.32


func _try_step_up(delta: float) -> void:
	if step_height <= 0.0 or not is_on_floor() or velocity.y > 0.1:
		return
	var horizontal_motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if horizontal_motion.length_squared() < 0.00001 or not test_move(global_transform, horizontal_motion):
		return
	var raised := global_transform.translated(Vector3.UP * step_height)
	if test_move(raised, horizontal_motion):
		return
	var advanced := raised.translated(horizontal_motion)
	if not test_move(advanced, Vector3.DOWN * (step_height + floor_snap_length + 0.04)):
		return
	global_position.y += step_height


func _on_landed(impact_speed: float) -> void:
	var strength := clampf((impact_speed - 2.0) / 8.0, 0.0, 1.0)
	_landing_velocity = -0.55 * strength
	landed.emit(impact_speed)


func _update_camera_feel(delta: float, input_strength: float) -> void:
	var bob_scale := float(SettingsService.get_value(&"accessibility", &"head_bob", 0.65))
	if is_on_floor() and input_strength > 0.05:
		_bob_time += delta * head_bob_frequency * (_get_target_speed() / walk_speed)
	_bob_weight = move_toward(_bob_weight, input_strength if is_on_floor() else 0.0, delta * 5.5)
	_landing_velocity += -_landing_offset * 65.0 * delta
	_landing_velocity *= exp(-10.0 * delta)
	_landing_offset += _landing_velocity * delta
	var lateral_speed := global_basis.x.dot(Vector3(velocity.x, 0.0, velocity.z))
	_camera_roll = lerpf(_camera_roll, clampf(-lateral_speed * 0.0022, -0.012, 0.012), clampf(delta * 7.0, 0.0, 1.0))
	var bob := Vector3(
		cos(_bob_time * 0.5) * head_bob_amount * 0.45,
		sin(_bob_time) * head_bob_amount,
		0.0
	) * bob_scale * _bob_weight
	bob.y += _landing_offset * bob_scale
	camera.position = camera.position.lerp(bob, clampf(delta * 12.0, 0.0, 1.0))
	camera.rotation.z = lerp_angle(camera.rotation.z, _camera_roll * bob_scale, clampf(delta * 10.0, 0.0, 1.0))


func _update_viewmodel(delta: float, input_strength: float) -> void:
	_viewmodel_look_offset = _viewmodel_look_offset.lerp(Vector2.ZERO, clampf(delta * 9.0, 0.0, 1.0))
	var movement_weight := clampf(input_strength, 0.0, 1.0) if is_on_floor() else 0.0
	var sprint_weight := 1.0 if movement_weight > 0.05 and _is_sprinting else 0.0
	var breathing := Vector3(sin(Time.get_ticks_msec() * 0.0014) * 0.0015, cos(Time.get_ticks_msec() * 0.0017) * 0.0018, 0.0)
	var gait := Vector3(
		cos(_bob_time * 0.5) * viewmodel_bob_amount,
		-sin(_bob_time) * viewmodel_bob_amount * 0.45,
		0.0
	) * movement_weight
	var inertia := Vector3(-_viewmodel_look_offset.x, _viewmodel_look_offset.y, 0.0)
	var sprint_lower := Vector3(0.015, -0.035, 0.035) * sprint_weight
	var crouch_lower := Vector3(0.0, -0.012, 0.012) if _is_crouched else Vector3.ZERO
	var landing_response := Vector3(0.0, _landing_offset * 1.8, -absf(_landing_offset) * 0.7)
	var target_position := _viewmodel_rest_position + gait + inertia + sprint_lower + crouch_lower + breathing + landing_response
	viewmodel.position = viewmodel.position.lerp(target_position, clampf(delta * 11.0, 0.0, 1.0))
	var target_rotation := Vector3(
		_viewmodel_look_offset.y * 0.8,
		_viewmodel_look_offset.x * 0.65,
		-cos(_bob_time * 0.5) * movement_weight * 0.018 - _viewmodel_look_offset.x * 0.45 + sprint_weight * 0.035
	)
	viewmodel.rotation = viewmodel.rotation.lerp(target_rotation, clampf(delta * 9.0, 0.0, 1.0))


func _update_steps() -> void:
	var planar_distance := Vector2(global_position.x - _last_position.x, global_position.z - _last_position.z).length()
	_last_position = global_position
	if not is_on_floor() or planar_distance <= 0.0:
		return
	_step_distance += planar_distance
	var sprinting := _is_sprinting and get_planar_speed() > walk_speed * 1.05
	var stride := 0.72 if _is_crouched else (1.25 if sprinting else 0.9)
	if _step_distance >= stride:
		_step_distance = 0.0
		var intensity := 0.28 if _is_crouched else (1.0 if sprinting else 0.55)
		noise_emitter.emit_noise(7.0 if intensity > 0.8 else 3.5, &"footstep", intensity)
		step_taken.emit(global_position, intensity)


func _push_rigid_bodies() -> void:
	if rigid_body_push_force <= 0.0:
		return
	for index: int in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var body := collision.get_collider() as RigidBody3D
		if body == null or body.freeze:
			continue
		var horizontal_normal := collision.get_normal()
		horizontal_normal.y = 0.0
		if horizontal_normal.length_squared() < 0.001:
			continue
		var push := -horizontal_normal.normalized() * minf(_pre_slide_planar_velocity.length() * rigid_body_push_force, 5.0)
		body.apply_central_impulse(push * 0.1)


func _on_tool_changed(_tool_id: StringName, is_equipped: bool) -> void:
	tool_state_changed.emit(toolbelt.get_display_name(), is_equipped)
