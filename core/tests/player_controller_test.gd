extends Node3D

var _failures := PackedStringArray()
var _landed_impacts: Array[float] = []
var _player: FirstPersonController


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ContentDB.rebuild()
	InputBootstrap.ensure_defaults()
	_add_static_box("Floor", Vector3(40.0, 0.2, 40.0), Vector3(0.0, -0.1, 0.0))
	_player = (load("res://features/player/player.tscn") as PackedScene).instantiate() as FirstPersonController
	add_child(_player)
	_player.global_position = Vector3(0.0, 0.05, 0.0)
	_player.set_gameplay_input_override_for_testing(true)
	_player.landed.connect(func(impact: float) -> void: _landed_impacts.append(impact))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _physics_frames(10)
	var first_person_arms := _player.get_node("CameraRig/Camera3D/ViewModel/RiggedFirstPersonArms")
	var arm_skeleton := first_person_arms.find_child("Skeleton3D", true, false) as Skeleton3D
	_expect(arm_skeleton != null and arm_skeleton.get_bone_count() >= 40, "Rigged CC0 first-person arms were not installed.")
	_expect(not (_player.get_node("CameraRig/Camera3D/ViewModel/KnifeViewModel/GripHand") as MeshInstance3D).visible, "Legacy primitive grip hand is still visible.")

	# Exercise a real physical key event, not Input.action_press(), so broken
	# device-specific project bindings cannot hide behind the test harness.
	var keyboard_start := _player.global_position
	_emit_physical_key(KEY_W, true)
	await _physics_frames(22)
	_emit_physical_key(KEY_W, false)
	_expect(_player.global_position.distance_to(keyboard_start) > 0.2, "Physical W key did not reach first-person movement.")
	await _physics_frames(18)

	# Analog input must preserve magnitude instead of snapping every stick tilt to full speed.
	Input.action_press(&"move_forward", 0.35)
	await _physics_frames(55)
	var analog_speed := _player.get_planar_speed()
	_expect(analog_speed > 0.7 and analog_speed < _player.walk_speed * 0.62, "Analog movement did not preserve stick magnitude: %.2f" % analog_speed)
	_expect(_player.avatar_animator.get_current_state() == &"walk", "Rigged avatar did not enter walk animation.")
	Input.action_release(&"move_forward")
	await _physics_frames(24)
	_expect(_player.get_planar_speed() < 0.12, "Ground deceleration left the player sliding.")

	# Sprint is forward-gated; holding sprint while reversing must not produce a backward sprint.
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _physics_frames(45)
	_expect(_player.get_planar_speed() > _player.walk_speed * 1.3 and _player.is_sprinting(), "Forward sprint failed to reach its authored gait.")
	_expect(_player.avatar_animator.get_current_state() == &"run", "Rigged avatar did not enter run animation.")
	Input.action_release(&"move_forward")
	Input.action_press(&"move_back")
	await _physics_frames(45)
	_expect(not _player.is_sprinting() and _player.get_planar_speed() <= _player.walk_speed + 0.15, "Backward input incorrectly retained sprint speed.")
	Input.action_release(&"move_back")
	Input.action_release(&"sprint")
	await _physics_frames(20)

	# Buffered jump, airborne animation and landing response are one locomotion contract.
	var takeoff_y := _player.global_position.y
	Input.action_press(&"jump")
	await get_tree().physics_frame
	Input.action_release(&"jump")
	await _physics_frames(8)
	_expect(_player.global_position.y > takeoff_y + 0.35, "Jump input did not lift the player.")
	_expect(_player.avatar_animator.get_current_state() == &"jump", "Rigged avatar did not enter jump animation.")
	for _frame: int in 100:
		await get_tree().physics_frame
		if _player.is_grounded() and not _landed_impacts.is_empty(): break
	_expect(not _landed_impacts.is_empty() and _landed_impacts.back() > 2.0, "Landing impact was not detected.")
	_expect(absf(float(_player.get("_landing_velocity"))) > 0.001 or absf(float(_player.get("_landing_offset"))) > 0.001, "Landing produced no camera spring response.")

	# Crouch changes the physical capsule and blocks jumping until standing clearance exists.
	Input.action_press(&"crouch")
	await _physics_frames(8)
	var capsule := _player.collision_shape.shape as CapsuleShape3D
	_expect(_player.is_crouched() and capsule.height < FirstPersonController.STANDING_BODY_HEIGHT, "Crouch did not resize the physical capsule.")
	var crouched_y := _player.global_position.y
	Input.action_press(&"jump")
	await _physics_frames(4)
	Input.action_release(&"jump")
	_expect(_player.global_position.y < crouched_y + 0.08, "Crouched player was allowed to jump.")
	Input.action_release(&"crouch")
	await _physics_frames(12)

	# The capsule must stop at world collision without visible tunnelling.
	_add_static_box("Wall", Vector3(5.0, 3.0, 0.25), Vector3(0.0, 1.5, -4.0))
	_player.global_position = Vector3(0.0, 0.05, -1.0)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	Input.action_press(&"move_forward")
	await _physics_frames(80)
	Input.action_release(&"move_forward")
	_expect(_player.global_position.z > -3.72, "Player capsule crossed the collision wall: z %.2f" % _player.global_position.z)

	# Low natural obstacles are stepped over, not treated like chest-high walls.
	(get_node("Wall") as StaticBody3D).queue_free()
	await get_tree().physics_frame
	_add_static_box("LowStep", Vector3(2.5, 0.22, 1.0), Vector3(0.0, 0.11, -2.3))
	_player.global_position = Vector3(0.0, 0.05, -0.8)
	_player.velocity = Vector3.ZERO
	Input.action_press(&"move_forward")
	var maximum_step_y := _player.global_position.y
	for _frame: int in 55:
		await get_tree().physics_frame
		maximum_step_y = maxf(maximum_step_y, _player.global_position.y)
	Input.action_release(&"move_forward")
	_expect(_player.global_position.z < -2.45, "Player snagged on a low step instead of traversing it.")
	_expect(maximum_step_y > 0.14, "Step traversal did not place the capsule on the obstacle surface.")

	# Lightweight loose objects receive bounded physical pushes from the capsule.
	(get_node("LowStep") as StaticBody3D).queue_free()
	var loose_box := _add_rigid_box(Vector3(0.0, 0.35, -6.0))
	_player.global_position = Vector3(0.0, 0.05, -4.6)
	_player.velocity = Vector3.ZERO
	await _physics_frames(8)
	var loose_start_z := loose_box.global_position.z
	Input.action_press(&"move_forward")
	await _physics_frames(55)
	Input.action_release(&"move_forward")
	_expect(loose_box.global_position.z < loose_start_z - 0.03, "Character collision did not push a lightweight rigid body.")

	_release_inputs()
	_player.queue_free()
	await get_tree().process_frame
	_finish()


func _add_static_box(node_name: String, size: Vector3, position_value: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _add_rigid_box(position_value: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "LooseFieldObject"
	body.mass = 0.7
	body.collision_mask = 3
	body.position = position_value
	body.lock_rotation = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.55, 0.7, 0.55)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body


func _physics_frames(count: int) -> void:
	for _frame: int in count: await get_tree().physics_frame


func _release_inputs() -> void:
	for action: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"crouch", &"jump"]:
		Input.action_release(action)


func _emit_physical_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.device = -1
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip player controller test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures: push_error(failure)
	print("TRip player controller test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
