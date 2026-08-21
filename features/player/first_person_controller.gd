class_name FirstPersonController
extends CharacterBody3D

signal step_taken(origin: Vector3, intensity: float)
signal inventory_requested
signal journal_requested
signal tool_state_changed(display_name: String, is_equipped: bool)
signal distraction_created(projectile: DistractionProjectile)
signal distraction_count_changed(remaining: int)

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

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var _look_pitch: float = 0.0
var _bob_time: float = 0.0
var _step_distance: float = 0.0
var _last_position: Vector3
var _is_crouched: bool = false
var _viewmodel_rest_position: Vector3
var _viewmodel_look_offset: Vector2 = Vector2.ZERO
var _spore_vision_active: bool = false
var _spore_resistance: float = 0.0
var _crimson_drive_amount: float = 0.0
var _consumption_tween: Tween

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
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
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
	_update_gamepad_look(delta)
	_update_stance(delta)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		velocity.x = move_toward(velocity.x, 0.0, ground_acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, ground_acceleration * delta)
		_apply_gravity(delta)
		move_and_slide()
		_update_viewmodel(delta, 0.0)
		return

	var input_vector := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var world_direction := (global_basis * local_direction).normalized()
	var target_speed := _get_target_speed()
	var acceleration := ground_acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, world_direction.x * target_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, world_direction.z * target_speed, acceleration * delta)
	_apply_gravity(delta)
	move_and_slide()
	_update_camera_feel(delta, input_vector.length())
	_update_viewmodel(delta, input_vector.length())
	_update_steps()


func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func get_stealth_exposure() -> float:
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var movement_exposure := remap(clampf(planar_speed, 0.0, sprint_speed), 0.0, sprint_speed, 0.72, 1.35)
	var stance_exposure := 0.48 if _is_crouched else 1.0
	var perception_price := 1.28 if _spore_vision_active else 1.0
	var crimson_price := lerpf(1.0, 1.45, _crimson_drive_amount)
	var quieting := lerpf(1.0, 0.72, _spore_resistance)
	return clampf(movement_exposure * stance_exposure * perception_price * crimson_price * quieting, 0.25, 1.9)


func set_spore_vision_active(value: bool) -> void:
	_spore_vision_active = value


func set_spore_resistance(value: float) -> void:
	_spore_resistance = clampf(value, 0.0, 1.0)


func set_crimson_drive(value: float) -> void:
	_crimson_drive_amount = clampf(value, 0.0, 1.0)


func play_consumption_animation(_effect_ids: Array[StringName], _display_name: String) -> void:
	if _consumption_tween != null and _consumption_tween.is_valid():
		_consumption_tween.kill()
	var resting_position := vial_viewmodel.position
	var resting_rotation := vial_viewmodel.rotation
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
	if _is_crouched:
		return crouch_speed * drive_multiplier
	if Input.is_action_pressed(&"sprint"):
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


func _update_camera_feel(delta: float, input_strength: float) -> void:
	var bob_scale := float(SettingsService.get_value(&"accessibility", &"head_bob", 0.65))
	if is_on_floor() and input_strength > 0.05:
		_bob_time += delta * head_bob_frequency * (_get_target_speed() / walk_speed)
	else:
		_bob_time = move_toward(_bob_time, 0.0, delta * head_bob_frequency)
	var bob := Vector3(
		cos(_bob_time * 0.5) * head_bob_amount * 0.45,
		sin(_bob_time) * head_bob_amount,
		0.0
	) * bob_scale
	camera.position = camera.position.lerp(bob, clampf(delta * 12.0, 0.0, 1.0))


func _update_viewmodel(delta: float, input_strength: float) -> void:
	_viewmodel_look_offset = _viewmodel_look_offset.lerp(Vector2.ZERO, clampf(delta * 9.0, 0.0, 1.0))
	var movement_weight := clampf(input_strength, 0.0, 1.0) if is_on_floor() else 0.0
	var gait := Vector3(
		cos(_bob_time * 0.5) * viewmodel_bob_amount,
		absf(sin(_bob_time)) * viewmodel_bob_amount * 0.7,
		0.0
	) * movement_weight
	var inertia := Vector3(-_viewmodel_look_offset.x, _viewmodel_look_offset.y, 0.0)
	var target_position := _viewmodel_rest_position + gait + inertia
	viewmodel.position = viewmodel.position.lerp(target_position, clampf(delta * 11.0, 0.0, 1.0))
	var target_rotation := Vector3(
		_viewmodel_look_offset.y * 0.8,
		_viewmodel_look_offset.x * 0.65,
		-cos(_bob_time * 0.5) * movement_weight * 0.018 - _viewmodel_look_offset.x * 0.45
	)
	viewmodel.rotation = viewmodel.rotation.lerp(target_rotation, clampf(delta * 9.0, 0.0, 1.0))


func _update_steps() -> void:
	var planar_distance := Vector2(global_position.x - _last_position.x, global_position.z - _last_position.z).length()
	_last_position = global_position
	if not is_on_floor() or planar_distance <= 0.0:
		return
	_step_distance += planar_distance
	var stride := 1.25 if Input.is_action_pressed(&"sprint") else 0.9
	if _step_distance >= stride:
		_step_distance = 0.0
		var intensity := 1.0 if Input.is_action_pressed(&"sprint") else 0.55
		noise_emitter.emit_noise(7.0 if intensity > 0.8 else 3.5, &"footstep", intensity)
		step_taken.emit(global_position, intensity)


func _on_tool_changed(_tool_id: StringName, is_equipped: bool) -> void:
	tool_state_changed.emit(toolbelt.get_display_name(), is_equipped)
