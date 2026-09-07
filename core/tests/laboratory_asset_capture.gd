extends Node3D

func _ready() -> void:
	var lab := load("res://features/road_laboratory/portable_laboratory.tscn").instantiate() as Node3D
	add_child(lab)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("202e30")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("a6bebd")
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_color = Color("ffe0b0")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(6.8, 3.3, 5.5)
	camera.fov = 50.0
	camera.look_at(Vector3(0, 1.0, -1.3))
	camera.current = true
	for frame in 8:
		await get_tree().process_frame
	var error := get_viewport().get_texture().get_image().save_png("/tmp/trip_laboratory_assets.png")
	print("Laboratory asset capture: ", error)
	get_tree().quit(error)
