extends Node3D

func _ready() -> void:
	var library := AuthoredNatureAssetLibrary.new()
	for i: int in 3:
		var tree := MeshInstance3D.new()
		tree.mesh = library.get_runtime_mesh(["cedar.glb", "fir.glb", "wind_cedar.glb"][i])
		tree.position = Vector3((i-1)*5.0,0,-i*1.5)
		add_child(tree)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40,40)
	ground.mesh = plane
	add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-35,-40,0)
	sun.shadow_enabled=true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("718891")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("718891")
	env.environment.ambient_light_energy=.5
	add_child(env)
	var camera := Camera3D.new()
	camera.position=Vector3(7,2,13)
	add_child(camera)
	camera.look_at(Vector3(0,4,0))
	camera.current=true
	for frame: int in 12: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/trip_conifers.png")
	get_tree().quit()
