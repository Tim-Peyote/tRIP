extends Node3D

const OUTPUT_PATH := "/tmp/trip_fps_arms_capture.png"


func _ready() -> void:
	var capture_args := OS.get_cmdline_user_args()
	ContentDB.rebuild()
	var player := (load("res://features/player/player.tscn") as PackedScene).instantiate() as FirstPersonController
	add_child(player)
	player.global_position = Vector3(0.0, 0.05, 0.0)
	player.set_gameplay_input_override_for_testing(true)
	await get_tree().process_frame
	player.toolbelt.equip(&"tool.field_knife")
	if "--vial" in capture_args:
		player.toolbelt.cycle_active_tool()
	if "--open" in capture_args:
		player.first_person_arm_rig.grip_amount = 0.0
		player.first_person_arm_rig.call("_apply_idle_grip")
	if "--hold" in capture_args:
		player.interactor.set_physics_process(false)
		player.call("_on_physical_hold_changed", true)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(16.0, 16.0)
	floor.mesh = floor_mesh
	floor.position = Vector3(0.0, 0.0, -4.0)
	add_child(floor)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	light.light_energy = 1.5
	add_child(light)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.095, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.42)
	env.ambient_light_energy = 0.7
	environment.environment = env
	add_child(environment)
	for _frame: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var skeleton := player.first_person_arm_rig.find_child("Skeleton3D", true, false) as Skeleton3D
	var hand := skeleton.find_bone("mixamorig_RightHand")
	if hand >= 0:
		print("FPS wrist camera position: ", player.camera.to_local(skeleton.global_transform * skeleton.get_bone_global_pose(hand).origin))
	print("FPS tool parent scale: ", player.knife_viewmodel.global_basis.get_scale())
	for mesh: Node in player.knife_viewmodel.find_children("*", "MeshInstance3D", true, false):
		print("Knife bounds: ", mesh.name, " ", (mesh as MeshInstance3D).get_aabb(), " transform ", (mesh as MeshInstance3D).transform)
	var image := get_viewport().get_texture().get_image()
	var output_path := "/tmp/trip_fps_arms_hold_capture.png" if "--hold" in capture_args else ("/tmp/trip_fps_arms_open_capture.png" if "--open" in capture_args else OUTPUT_PATH)
	var error := image.save_png(output_path)
	if error == OK:
		print("FPS arms capture saved: %s" % output_path)
	get_tree().quit(error)
