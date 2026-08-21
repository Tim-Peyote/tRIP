class_name MenuCampBackdrop
extends Node3D

var _camera: Camera3D
var _fire_light: OmniLight3D
var _flames: Array[MeshInstance3D] = []
var _upgrade_root: Node3D
var _time: float = 0.0
var _laboratory_level: int = 0


func _ready() -> void:
	_build_environment()
	_build_clearing()
	_build_fire()
	_build_field_lab()
	_build_seated_player()
	_build_forest_frame()
	refresh_from_save()
	set_process(true)


func refresh_from_save() -> void:
	var data := SaveService.load_slot(0)
	var loop_data := data.get("game_loop", {}) as Dictionary
	apply_progress_data(loop_data)


func apply_progress_data(loop_data: Dictionary) -> void:
	_laboratory_level = clampi(int(loop_data.get("completed_cycles", 0)), 0, 6)
	if bool(loop_data.get("second_expedition_complete", false)):
		_laboratory_level = maxi(_laboratory_level, 2)
	if bool(loop_data.get("counteragent_brewed", false)):
		_laboratory_level = maxi(_laboratory_level, 3)
	if String(loop_data.get("root_well_plan", "")) != "":
		_laboratory_level = maxi(_laboratory_level, 4)
	_rebuild_upgrades(loop_data)


func get_laboratory_level() -> int:
	return _laboratory_level


func get_visible_upgrade_names() -> PackedStringArray:
	var names := PackedStringArray()
	if _upgrade_root == null:
		return names
	for child: Node in _upgrade_root.get_children():
		if not child.is_queued_for_deletion():
			names.append(child.name)
	return names


func _process(delta: float) -> void:
	_time += delta
	if _fire_light != null:
		_fire_light.light_energy = 3.6 + sin(_time * 8.7) * 0.35 + sin(_time * 13.1) * 0.18
	for index in _flames.size():
		var flame := _flames[index]
		var pulse := 1.0 + sin(_time * (5.5 + index) + float(index) * 1.7) * 0.18
		flame.scale = Vector3(0.72 + index * 0.12, pulse, 0.72 + index * 0.12)
		flame.position.y = 0.62 + float(index) * 0.13 + sin(_time * 4.0 + index) * 0.035
	if _camera != null:
		var mouse := get_viewport().get_mouse_position()
		var viewport_size := get_viewport().get_visible_rect().size
		var parallax := Vector2.ZERO
		if viewport_size.x > 1.0 and viewport_size.y > 1.0:
			parallax = (mouse / viewport_size - Vector2(0.5, 0.5)) * 0.28
		_camera.position = Vector3(8.7 + parallax.x, 4.7 - parallax.y, 10.8)
		_camera.look_at(Vector3(0.2, 1.25, -0.3), Vector3.UP)


func _build_environment() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.012, 0.018, 0.075)
	sky_material.sky_horizon_color = Color(0.19, 0.055, 0.12)
	sky_material.ground_bottom_color = Color(0.008, 0.012, 0.018)
	sky_material.ground_horizon_color = Color(0.11, 0.035, 0.06)
	sky_material.sun_angle_max = 5.0
	sky_material.sun_curve = 0.12
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.17, 0.23, 0.38)
	environment.ambient_light_energy = 1.05
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.75
	environment.glow_bloom = 0.12
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.08, 0.12, 0.16)
	environment.fog_density = 0.018
	environment.fog_light_energy = 0.65
	environment_node.environment = environment
	add_child(environment_node)
	_camera = Camera3D.new()
	_camera.fov = 56.0
	_camera.position = Vector3(8.7, 4.7, 10.8)
	add_child(_camera)
	_camera.look_at(Vector3(0.2, 1.25, -0.3), Vector3.UP)
	var moon := DirectionalLight3D.new()
	moon.rotation = Vector3(-0.72, -0.55, 0.0)
	moon.light_color = Color(0.38, 0.48, 0.82)
	moon.light_energy = 1.4
	moon.shadow_enabled = true
	add_child(moon)
	var moon_disc := _mesh_node(_low_poly_sphere(2.15, 4.3), Color(0.82, 0.12, 0.58), true)
	moon_disc.position = Vector3(-2.8, 8.5, -17.5)
	add_child(moon_disc)
	_build_distant_mountains()


func _build_distant_mountains() -> void:
	for index in 11:
		var mountain := _cylinder(2.4 + float(index % 3) * 0.85, 6.5 + float(index % 4) * 1.4, Color(0.025, 0.035, 0.095), 5)
		(mountain.mesh as CylinderMesh).top_radius = 0.0
		mountain.position = Vector3(-19.0 + float(index) * 3.8, 2.2, -14.0 - absf(float(index) - 5.0) * 0.45)
		mountain.rotation.y = float(index) * 0.37
		add_child(mountain)


func _build_clearing() -> void:
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(34, 28)
	ground_mesh.subdivide_width = 10
	ground_mesh.subdivide_depth = 10
	ground_mesh.material = _material(Color(0.035, 0.075, 0.045))
	ground.mesh = ground_mesh
	add_child(ground)
	for index in 13:
		var angle := TAU * float(index) / 13.0
		var stone := _mesh_node(_low_poly_sphere(0.36, 0.34), Color(0.16, 0.17, 0.15))
		stone.position = Vector3(cos(angle) * 1.15, 0.18, sin(angle) * 1.15)
		stone.scale = Vector3(1.3, 0.58, 0.9)
		stone.rotation.y = angle
		add_child(stone)
	var rug := _box(Vector3(3.2, 0.025, 2.15), Color(0.18, 0.035, 0.028))
	rug.position = Vector3(3.25, 0.03, 1.0)
	rug.rotation.y = -0.18
	add_child(rug)


func _build_fire() -> void:
	for index in 5:
		var log := _cylinder(0.14, 2.2, Color(0.16, 0.055, 0.018), 7)
		log.position = Vector3(0, 0.24, 0)
		log.rotation = Vector3(0, float(index) * TAU / 5.0, PI * 0.5)
		add_child(log)
	for index in 3:
		var flame := _mesh_node(_low_poly_sphere(0.34 - index * 0.055, 0.9 - index * 0.12), Color(1.0, 0.16 + index * 0.14, 0.015), true)
		flame.position = Vector3((index - 1) * 0.16, 0.62 + index * 0.13, 0)
		add_child(flame)
		_flames.append(flame)
	_fire_light = OmniLight3D.new()
	_fire_light.position = Vector3(0, 1.0, 0)
	_fire_light.light_color = Color(1.0, 0.27, 0.055)
	_fire_light.light_energy = 3.8
	_fire_light.omni_range = 9.5
	_fire_light.shadow_enabled = true
	add_child(_fire_light)


func _build_field_lab() -> void:
	var lab := Node3D.new()
	lab.name = "RoadLaboratory"
	lab.position = Vector3(-3.25, 0, -0.35)
	lab.rotation.y = 0.16
	add_child(lab)
	var top := _box(Vector3(3.5, 0.16, 1.25), Color(0.24, 0.11, 0.035))
	top.position.y = 1.18
	lab.add_child(top)
	for x in [-1.45, 1.45]:
		for z in [-0.43, 0.43]:
			var leg := _box(Vector3(0.14, 1.18, 0.14), Color(0.15, 0.055, 0.018))
			leg.position = Vector3(x, 0.59, z)
			lab.add_child(leg)
	var cauldron := _cylinder(0.48, 0.54, Color(0.035, 0.045, 0.05), 12)
	cauldron.position = Vector3(-0.55, 1.52, 0)
	lab.add_child(cauldron)
	var liquid := _cylinder(0.4, 0.035, Color(0.38, 0.75, 0.12), 16, true)
	liquid.position = Vector3(-0.55, 1.79, 0)
	lab.add_child(liquid)
	var mortar := _cylinder(0.32, 0.3, Color(0.24, 0.27, 0.22), 10)
	mortar.position = Vector3(0.58, 1.42, 0.12)
	lab.add_child(mortar)
	var pestle := _cylinder(0.07, 0.72, Color(0.29, 0.22, 0.12), 8)
	pestle.position = Vector3(0.72, 1.77, 0.08)
	pestle.rotation.z = -0.42
	lab.add_child(pestle)
	_upgrade_root = Node3D.new()
	_upgrade_root.name = "PersistentUpgrades"
	lab.add_child(_upgrade_root)


func _build_seated_player() -> void:
	var actor := Node3D.new()
	actor.name = "SeatedResearcher"
	actor.position = Vector3(3.05, 0.0, 0.35)
	actor.rotation.y = -1.15
	add_child(actor)
	var torso := _box(Vector3(0.72, 1.15, 0.42), Color(0.035, 0.085, 0.09))
	torso.position = Vector3(0, 1.18, 0)
	torso.rotation.x = 0.14
	actor.add_child(torso)
	var head := _mesh_node(_low_poly_sphere(0.31, 0.55), Color(0.34, 0.22, 0.14))
	head.position = Vector3(0, 1.98, -0.05)
	actor.add_child(head)
	for side in [-1.0, 1.0]:
		var upper_leg := _cylinder(0.12, 0.86, Color(0.045, 0.07, 0.075), 7)
		upper_leg.position = Vector3(side * 0.22, 0.63, 0.28)
		upper_leg.rotation.x = PI * 0.5
		actor.add_child(upper_leg)
		var lower_leg := _cylinder(0.105, 0.82, Color(0.035, 0.055, 0.06), 7)
		lower_leg.position = Vector3(side * 0.22, 0.28, 0.7)
		actor.add_child(lower_leg)
		var arm := _cylinder(0.085, 0.82, Color(0.045, 0.095, 0.095), 7)
		arm.position = Vector3(side * 0.42, 1.27, -0.16)
		arm.rotation.z = side * 0.42
		actor.add_child(arm)


func _build_forest_frame() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 44031
	for index in 34:
		# Leave a deliberate view corridor between the camera and the camp.
		var angle := rng.randf_range(-0.72, 0.18) if index % 2 == 0 else rng.randf_range(1.72, PI + 0.72)
		var radius := rng.randf_range(8.0, 16.0)
		var tree := Node3D.new()
		tree.position = Vector3(cos(angle) * radius, 0, sin(angle) * radius - 2.0)
		var scale_value := rng.randf_range(0.8, 1.75)
		var trunk := _cylinder(0.24, 5.4, Color(0.075, 0.032, 0.02), 6)
		trunk.position.y = 2.7 * scale_value
		trunk.scale = Vector3.ONE * scale_value
		tree.add_child(trunk)
		for layer in 3:
			var crown := _cylinder(1.45 - layer * 0.24, 1.85, Color(0.025, 0.105 + layer * 0.018, 0.055), 7)
			(crown.mesh as CylinderMesh).top_radius = 0.0
			crown.position.y = scale_value * (4.4 + layer * 1.05)
			crown.scale = Vector3.ONE * scale_value
			tree.add_child(crown)
		add_child(tree)


func _rebuild_upgrades(loop_data: Dictionary) -> void:
	if _upgrade_root == null:
		return
	for child: Node in _upgrade_root.get_children():
		_upgrade_root.remove_child(child)
		child.queue_free()
	if _laboratory_level >= 1:
		_add_drying_rack()
	if _laboratory_level >= 2:
		_add_spore_filter()
	if _laboratory_level >= 3:
		_add_distiller()
	if _laboratory_level >= 4:
		_add_root_resonator(StringName(loop_data.get("root_well_plan", "")))


func _add_drying_rack() -> void:
	var rack := Node3D.new()
	rack.name = "DryingRack"
	rack.position = Vector3(1.38, 0, -0.85)
	for x in [-0.55, 0.55]:
		var post := _box(Vector3(0.1, 2.5, 0.1), Color(0.2, 0.075, 0.025))
		post.position = Vector3(x, 1.25, 0)
		rack.add_child(post)
	for y in [1.15, 1.75, 2.25]:
		var rail := _box(Vector3(1.25, 0.07, 0.07), Color(0.25, 0.09, 0.025))
		rail.position.y = y
		rack.add_child(rail)
		for x in [-0.38, 0.0, 0.38]:
			var herb := _mesh_node(_low_poly_sphere(0.12, 0.42), Color(0.32, 0.22 + y * 0.04, 0.055))
			herb.position = Vector3(x, y - 0.24, 0)
			rack.add_child(herb)
	_upgrade_root.add_child(rack)


func _add_spore_filter() -> void:
	var filter := _cylinder(0.26, 1.1, Color(0.13, 0.42, 0.34), 10, true)
	filter.name = "SporeFilter"
	filter.position = Vector3(-1.15, 1.85, 0)
	_upgrade_root.add_child(filter)


func _add_distiller() -> void:
	var coil := _mesh_node(TorusMesh.new(), Color(0.78, 0.25, 0.07), true)
	(coil.mesh as TorusMesh).inner_radius = 0.28
	(coil.mesh as TorusMesh).outer_radius = 0.4
	coil.name = "DistillerCoil"
	coil.position = Vector3(1.1, 1.75, 0.1)
	coil.rotation.x = PI * 0.5
	_upgrade_root.add_child(coil)


func _add_root_resonator(plan: StringName) -> void:
	var color := Color(0.16, 0.8, 0.48) if plan == &"warded_descent" else Color(0.9, 0.08, 0.52)
	var ring := _mesh_node(TorusMesh.new(), color, true)
	(ring.mesh as TorusMesh).inner_radius = 0.42
	(ring.mesh as TorusMesh).outer_radius = 0.56
	ring.name = "RootResonator"
	ring.position = Vector3(0.15, 2.2, -0.35)
	ring.rotation.x = PI * 0.5
	_upgrade_root.add_child(ring)


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh_node(mesh, color)


func _cylinder(radius: float, height: float, color: Color, segments: int, emission: bool = false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.82
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	return _mesh_node(mesh, color, emission)


func _low_poly_sphere(radius: float, height: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 7
	mesh.rings = 4
	return mesh


func _mesh_node(mesh: PrimitiveMesh, color: Color, emission: bool = false) -> MeshInstance3D:
	mesh.material = _material(color, emission)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance


func _material(color: Color, emission: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.4
	return material
