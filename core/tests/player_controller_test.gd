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
	var foley := _player.find_child("PlayerFoley", true, false) as PlayerFoley
	for stream: AudioStream in foley.get("_step_streams"):
		_expect(stream is AudioStreamOggVorbis, "Player step still uses a generated stream.")
	_expect(foley.get("_jump_stream") is AudioStreamOggVorbis, "Player jump still uses a generated stream.")
	_expect(foley.get("_land_stream") is AudioStreamOggVorbis, "Player landing still uses a generated stream.")
	_player.landed.connect(func(impact: float) -> void: _landed_impacts.append(impact))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _physics_frames(10)
	var first_person_arms := _player.get_node("CameraRig/Camera3D/ViewModel/RiggedFirstPersonArms")
	var arm_skeleton := first_person_arms.find_child("Skeleton3D", true, false) as Skeleton3D
	_expect(arm_skeleton != null and arm_skeleton.get_bone_count() >= 40, "Rigged CC0 first-person arms were not installed.")
	_expect(InputMap.has_action(&"toggle_view") and _action_has_physical_key(&"toggle_view", KEY_V), "Camera view toggle is not bound to physical V.")
	_emit_physical_key(KEY_V, true)
	await get_tree().process_frame
	_emit_physical_key(KEY_V, false)
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame
	_expect(_player.is_third_person_enabled(), "Physical V did not enable third-person view.")
	_expect(_player.third_person_camera.current and not _player.camera.current, "Third-person camera did not become the active renderer.")
	_expect(not _player.viewmodel.visible, "First-person arms remained visible in third-person view.")
	_expect(_player.avatar_animator.is_third_person_visible(), "Full player body remained shadow-only in third-person view.")
	# This imported rig is authored facing +Z; its visible forward, rather than
	# the conventional Godot -Z node forward, must follow controller travel.
	var avatar_forward := _player.avatar_animator.global_basis.z.normalized()
	var controller_forward := -_player.global_basis.z.normalized()
	_expect(avatar_forward.dot(controller_forward) > 0.99, "Third-person avatar faces backward relative to the controller movement direction.")
	_expect(_player.third_person_spring_arm.collision_mask == 1 and _player.third_person_spring_arm.spring_length > 0.3, "Third-person camera lacks an authored collision spring arm.")
	_expect(_player.interactor.global_position.distance_to(_player.third_person_camera.global_position) < 0.02, "Interaction ray did not follow the rendered third-person camera.")
	_add_static_box("CameraOccluder", Vector3(3.0, 3.2, 0.2), Vector3(0.42, 1.55, 1.45))
	await _physics_frames(5)
	_expect(_player.third_person_camera.global_position.distance_to(_player.third_person_spring_arm.global_position) < 1.6, "Spring arm let the third-person camera pass through a wall.")
	(get_node("CameraOccluder") as StaticBody3D).queue_free()
	await get_tree().physics_frame
	_player.set_camera_fov(83.0)
	_expect(is_equal_approx(_player.camera.fov, 83.0) and is_equal_approx(_player.third_person_camera.fov, 83.0), "FOV setting did not update both camera modes.")
	_emit_physical_key(KEY_V, true)
	await get_tree().process_frame
	_emit_physical_key(KEY_V, false)
	await get_tree().process_frame
	_expect(not _player.is_third_person_enabled() and _player.camera.current, "Second V press did not restore first-person view.")
	_expect(_player.viewmodel.visible and not _player.avatar_animator.is_third_person_visible(), "First-person body/arms representation was not restored.")
	var legacy_grip := _player.get_node("CameraRig/Camera3D/ViewModel/PrototypeKnifeViewModel/GripHand") as MeshInstance3D
	var knife_attachment := _player.knife_viewmodel as BoneAttachment3D
	_expect(not legacy_grip.visible, "Legacy primitive grip hand is still visible.")
	_expect(knife_attachment != null and knife_attachment.bone_name == "socket.r", "Authored knife is not attached to the right-hand rig socket.")
	_expect(knife_attachment.find_child("AuthoredKnife", true, false) != null, "Authored CC0 knife is missing from the viewmodel.")
	var offhand_index := arm_skeleton.find_bone("shoulder.l")
	_expect(offhand_index >= 0 and arm_skeleton.get_bone_pose_scale(offhand_index).x < 0.01, "Unused offhand is still hanging in the normal exploration view.")
	var held_probe := _add_rigid_box(Vector3(0.0, 0.35, -1.5))
	_player.interactor.call("_begin_grab", held_probe)
	_expect(arm_skeleton.get_bone_pose_scale(offhand_index).x < 0.01, "Physical interaction exposed the unanimated offhand.")
	_expect(not first_person_arms.visible, "Generic physical grab exposed an unanchored hand pose.")
	_expect(not knife_attachment.visible, "Equipped tool remained visible through a physical interaction.")
	_player.interactor.call("_release_grabbed_body")
	_expect(first_person_arms.visible and arm_skeleton.get_bone_pose_scale(offhand_index).x < 0.01 and knife_attachment.visible, "Exploration hand pose was not restored after releasing an object.")
	held_probe.queue_free()
	await get_tree().physics_frame

	# Exercise a real physical key event, not Input.action_press(), so broken
	# device-specific project bindings cannot hide behind the test harness. Remove
	# the mapped keyboard event first: movement must still pass through the raw
	# physical-key bridge used by embedded game windows.
	for event: InputEvent in InputMap.action_get_events(&"move_forward"):
		if event is InputEventKey:
			InputMap.action_erase_event(&"move_forward", event)
	var keyboard_start := _player.global_position
	_emit_physical_key(KEY_W, true)
	await _physics_frames(22)
	_emit_physical_key(KEY_W, false)
	_expect(_player.global_position.distance_to(keyboard_start) > 0.2, "Raw physical W key did not reach first-person movement without InputMap.")
	InputBootstrap.ensure_defaults()
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

	# Locomotion clips must survive several animation lengths. Imported FBX
	# clips defaulted to one-shot playback and used to freeze while movement
	# continued after the first cycle.
	_player.set_third_person_enabled(true, false)
	Input.action_press(&"move_forward")
	await _physics_frames(240)
	var avatar_animation_player := _player.avatar_animator.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var walk_animation := avatar_animation_player.get_animation(&"Human Armature|Walk")
	var run_animation := avatar_animation_player.get_animation(&"Human Armature|Run")
	_expect(_player.get_planar_speed() > 1.0, "Player stopped during the sustained third-person locomotion test.")
	_expect(_player.avatar_animator.get_current_state() == &"walk", "Third-person walk state was lost during sustained movement.")
	_expect(avatar_animation_player.is_playing(), "Third-person walk animation stopped while the character was still moving.")
	_expect(walk_animation != null and walk_animation.loop_mode == Animation.LOOP_LINEAR, "Third-person walk clip is not configured as a locomotion loop.")
	_expect(run_animation != null and run_animation.loop_mode == Animation.LOOP_LINEAR, "Third-person run clip is not configured as a locomotion loop.")
	var travel_direction := Vector3(_player.velocity.x, 0.0, _player.velocity.z).normalized()
	var visible_forward := _player.avatar_animator.global_basis.z.normalized()
	_expect(visible_forward.dot(travel_direction) > 0.98, "Third-person body did not turn toward sustained travel direction.")
	Input.action_release(&"move_forward")
	await _physics_frames(24)
	_player.set_third_person_enabled(false, false)

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
	for event: InputEvent in InputMap.action_get_events(&"jump"):
		if event is InputEventKey:
			InputMap.action_erase_event(&"jump", event)
	_emit_physical_key(KEY_SPACE, true)
	await get_tree().physics_frame
	_emit_physical_key(KEY_SPACE, false)
	await _physics_frames(8)
	_expect(_player.global_position.y > takeoff_y + 0.35, "Raw physical Space did not lift the player without InputMap.")
	InputBootstrap.ensure_defaults()
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


func _action_has_physical_key(action: StringName, keycode: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false


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
