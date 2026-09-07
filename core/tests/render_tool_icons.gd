extends Node

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/ui/tool_icons")
	var sources := {
		"field_knife": "res://assets/third_party/oga_low_poly_knife/knife.fbx",
		"field_shovel": "res://assets/third_party/kenney_survival_kit/tool-shovel.glb",
		"spore_vial": "res://assets/models/laboratory/spirit_flask.glb",
	}
	for key in sources:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(256, 256)
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.msaa_3d = Viewport.MSAA_4X
		add_child(viewport)
		var model := (load(sources[key]) as PackedScene).instantiate() as Node3D
		viewport.add_child(model)
		if key == "spore_vial":
			model.free()
			model = Node3D.new()
			viewport.add_child(model)
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(0.34, 0.5, 0.49, 0.72)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.roughness = 0.18
			var tube := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.075
			cylinder.bottom_radius = 0.075
			cylinder.height = 0.46
			cylinder.material = glass
			tube.mesh = cylinder
			model.add_child(tube)
			var stopper := MeshInstance3D.new()
			var cork := CylinderMesh.new()
			cork.top_radius = 0.08
			cork.bottom_radius = 0.073
			cork.height = 0.065
			var cork_material := StandardMaterial3D.new()
			cork_material.albedo_color = Color("806044")
			cork.material = cork_material
			stopper.mesh = cork
			stopper.position.y = 0.245
			model.add_child(stopper)
		var bounds := AABB()
		var first := true
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = node.global_transform * node.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var center := bounds.get_center()
		var extent := maxf(bounds.size.length(), 0.01)
		var camera := Camera3D.new()
		viewport.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = extent * 1.15
		camera.near = extent * 0.001
		camera.far = extent * 10.0
		camera.position = center + Vector3(0.45, 0.25, 1.0).normalized() * extent * 2.0
		camera.look_at(center)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-30, -35, 0)
		light.light_energy = 2.0
		viewport.add_child(light)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 0.7
		viewport.add_child(environment)
		for frame in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var error := viewport.get_texture().get_image().save_png("res://assets/ui/tool_icons/%s.png" % key)
		if error != OK: get_tree().quit(error); return
		viewport.queue_free()
		await get_tree().process_frame
	print("Tool icons rendered")
	get_tree().quit()
