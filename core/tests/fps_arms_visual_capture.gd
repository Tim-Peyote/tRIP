extends Node3D

const OUTPUT_PATH := "/tmp/trip_fps_arms_capture.png"


func _ready() -> void:
	ContentDB.rebuild()
	var player := (load("res://features/player/player.tscn") as PackedScene).instantiate() as FirstPersonController
	add_child(player)
	player.global_position = Vector3(0.0, 0.05, 0.0)
	player.set_gameplay_input_override_for_testing(true)
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
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error == OK:
		print("FPS arms capture saved: %s" % OUTPUT_PATH)
	get_tree().quit(error)
