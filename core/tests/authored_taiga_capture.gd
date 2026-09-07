extends Node3D

func _ready() -> void:
	for i in 6:
		var file: String = ["maral", "musk_deer", "wolf", "bear", "sable", "eagle"][i]
		var actor := load("res://assets/models/actors/%s.glb" % file).instantiate() as Node3D
		add_child(actor)
		actor.position = Vector3(-5.0 + i * 2.0, 0, 0)
		var player := actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
		player.play(&"Idle")
	for i in 4:
		var tree := load("res://assets/models/taiga/%s.glb" % ["cedar", "fir", "young_fir", "wind_cedar"][i]).instantiate() as Node3D
		add_child(tree)
		tree.position = Vector3(-7.0+i*4.5,0,-5)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(35,35)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("303a25")
	ground.material_override = mat
	add_child(ground)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-25,0)
	light.light_color = Color("ffe0b0")
	light.shadow_enabled = true
	add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("6c8b91")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("819eaa")
	env.environment.ambient_light_energy = .8
	add_child(env)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(8,5,15)
	camera.look_at(Vector3(0,2,-2))
	camera.current = true
	for frame in 10: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/tmp/trip_taiga_assets.png")
	get_tree().quit()
