class_name BiomeDressingScatter
extends Node3D

@export var area_size: Vector2 = Vector2(38, 38)
@export var base_seed: int = 7217
@export_range(0, 100, 1) var conifer_count: int = 34
@export_range(0, 100, 1) var broadleaf_count: int = 22
@export_range(0, 60, 1) var snag_count: int = 10
@export_range(0, 160, 1) var rock_count: int = 52
@export_range(0, 60, 1) var log_count: int = 12
@export_range(0, 40, 1) var distant_ridge_count: int = 18
@export_range(0, 40, 1) var terrain_mound_count: int = 16
@export_range(0.0, 8.0, 0.1) var trail_half_width: float = 2.4
@export_range(0.0, 12.0, 0.1) var landmark_clear_radius: float = 4.0
@export var ground_color: Color = Color(0.055, 0.095, 0.055)
@export var bark_color: Color = Color(0.16, 0.075, 0.032)
@export var canopy_dark: Color = Color(0.035, 0.13, 0.055)
@export var canopy_light: Color = Color(0.1, 0.26, 0.09)
@export var stone_dark: Color = Color(0.12, 0.14, 0.13)
@export var stone_light: Color = Color(0.25, 0.28, 0.23)

var _run_seed: int = 0
var _generation_signature: int = 0


func _ready() -> void:
	_rebuild()


func set_run_seed(value: int) -> void:
	if _run_seed == value:
		return
	_run_seed = value
	_rebuild()


func _rebuild() -> void:
	for child: Node in get_children():
		if child.has_meta(&"generated_biome_dressing"):
			child.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(base_seed) * 1000003 + int(_run_seed)
	_build_ground()
	_build_terrain_mounds(rng)
	_build_conifers(rng)
	_build_broadleaves(rng)
	_build_snags(rng)
	_build_rocks(rng)
	_build_logs(rng)
	_build_distant_ridges(rng)
	_generation_signature = rng.state


func get_generation_signature() -> int:
	return _generation_signature


func _build_terrain_mounds(rng: RandomNumberGenerator) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 2.2
	mesh.height = 1.2
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _material(ground_color.lightened(0.08), true)
	var multimesh := _multimesh(mesh, terrain_mound_count, true)
	for index in terrain_mound_count:
		var point := _sample_mound_position(rng)
		var size := rng.randf_range(0.7, 1.3)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(size * rng.randf_range(1.0, 1.8), size * rng.randf_range(0.35, 0.75), size))
		multimesh.set_instance_transform(index, Transform3D(basis, point + Vector3.UP * 0.18 * size))
		multimesh.set_instance_color(index, ground_color.lerp(canopy_dark, rng.randf_range(0.05, 0.35)))
	_add_multimesh("TerrainMounds", multimesh)


func _sample_mound_position(rng: RandomNumberGenerator) -> Vector3:
	for _attempt in 32:
		var point := Vector3(rng.randf_range(-area_size.x * 0.5, area_size.x * 0.5), 0.0, rng.randf_range(-area_size.y * 0.5, area_size.y * 0.5))
		if point.length() >= landmark_clear_radius + 2.0 and absf(point.x) >= trail_half_width + 3.0:
			return point
	return Vector3(area_size.x * 0.4, 0, area_size.y * 0.4)


func _build_ground() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = area_size
	mesh.subdivide_width = 8
	mesh.subdivide_depth = 8
	mesh.material = _material(ground_color, false)
	var instance := MeshInstance3D.new()
	instance.name = "DistantGround"
	instance.position.y = -0.015
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_generated(instance)


func _build_conifers(rng: RandomNumberGenerator) -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.13
	trunk_mesh.bottom_radius = 0.32
	trunk_mesh.height = 4.8
	trunk_mesh.radial_segments = 6
	trunk_mesh.material = _material(bark_color, true)
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.0
	crown_mesh.bottom_radius = 1.25
	crown_mesh.height = 2.2
	crown_mesh.radial_segments = 7
	crown_mesh.material = _material(canopy_dark, true)
	var trunks := _multimesh(trunk_mesh, conifer_count, true)
	var crowns := _multimesh(crown_mesh, conifer_count * 3, true)
	for index in conifer_count:
		var point := _sample_position(rng, true)
		var size := rng.randf_range(0.72, 1.5)
		var yaw := rng.randf_range(0.0, TAU)
		var lean := rng.randf_range(-0.055, 0.055)
		var trunk_basis := Basis.from_euler(Vector3(lean, yaw, lean * 0.6)).scaled(Vector3(size, size, size))
		trunks.set_instance_transform(index, Transform3D(trunk_basis, point + Vector3.UP * 2.4 * size))
		trunks.set_instance_color(index, bark_color.lerp(Color(0.26, 0.12, 0.045), rng.randf_range(0.0, 0.5)))
		for layer in 3:
			var layer_scale := size * (1.18 - float(layer) * 0.22)
			var crown_basis := Basis(Vector3.UP, yaw + float(layer) * 0.18).scaled(Vector3(layer_scale, size, layer_scale))
			var crown_position := point + Vector3.UP * size * (3.65 + float(layer) * 1.12)
			var crown_index := index * 3 + layer
			crowns.set_instance_transform(crown_index, Transform3D(crown_basis, crown_position))
			crowns.set_instance_color(crown_index, canopy_dark.lerp(canopy_light, rng.randf_range(0.05, 0.72)))
	_add_multimesh("ConiferTrunks", trunks)
	_add_multimesh("ConiferCrowns", crowns)


func _build_broadleaves(rng: RandomNumberGenerator) -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.38
	trunk_mesh.height = 4.3
	trunk_mesh.radial_segments = 7
	trunk_mesh.material = _material(bark_color.lightened(0.08), true)
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.15
	crown_mesh.height = 1.8
	crown_mesh.radial_segments = 7
	crown_mesh.rings = 4
	crown_mesh.material = _material(canopy_light, true)
	var trunks := _multimesh(trunk_mesh, broadleaf_count, true)
	var crowns := _multimesh(crown_mesh, broadleaf_count * 3, true)
	for index in broadleaf_count:
		var point := _sample_position(rng, true)
		var size := rng.randf_range(0.68, 1.35)
		var yaw := rng.randf_range(0.0, TAU)
		trunks.set_instance_transform(index, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(size, size, size)), point + Vector3.UP * 2.15 * size))
		trunks.set_instance_color(index, bark_color.lerp(Color(0.32, 0.14, 0.055), rng.randf_range(0.1, 0.6)))
		for crown in 3:
			var angle := yaw + float(crown) * TAU / 3.0
			var offset := Vector3(cos(angle), 0.15 * float(crown), sin(angle)) * size * 0.72
			var crown_scale := size * rng.randf_range(0.78, 1.15)
			var crown_index := index * 3 + crown
			crowns.set_instance_transform(crown_index, Transform3D(Basis(Vector3.UP, angle).scaled(Vector3(crown_scale, crown_scale * 0.72, crown_scale)), point + Vector3.UP * size * 4.35 + offset))
			crowns.set_instance_color(crown_index, canopy_dark.lerp(canopy_light, rng.randf_range(0.35, 1.0)))
	_add_multimesh("BroadleafTrunks", trunks)
	_add_multimesh("BroadleafCrowns", crowns)


func _build_snags(rng: RandomNumberGenerator) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.08
	mesh.bottom_radius = 0.34
	mesh.height = 5.5
	mesh.radial_segments = 5
	mesh.material = _material(bark_color.darkened(0.18), true)
	var multimesh := _multimesh(mesh, snag_count, true)
	for index in snag_count:
		var point := _sample_position(rng, true)
		var size := rng.randf_range(0.55, 1.25)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(0.0, TAU), rng.randf_range(-0.12, 0.12))).scaled(Vector3(size, size, size))
		multimesh.set_instance_transform(index, Transform3D(basis, point + Vector3.UP * 2.75 * size))
		multimesh.set_instance_color(index, bark_color.darkened(rng.randf_range(0.05, 0.3)))
	_add_multimesh("DeadSnags", multimesh)


func _build_rocks(rng: RandomNumberGenerator) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.75
	mesh.height = 1.1
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = _material(stone_dark, true)
	var multimesh := _multimesh(mesh, rock_count, true)
	for index in rock_count:
		var point := _sample_position(rng, true)
		var size := rng.randf_range(0.3, 1.45)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.22, 0.22), rng.randf_range(0.0, TAU), rng.randf_range(-0.18, 0.18))).scaled(Vector3(size * rng.randf_range(0.7, 1.45), size * rng.randf_range(0.45, 0.95), size))
		multimesh.set_instance_transform(index, Transform3D(basis, point + Vector3.UP * size * 0.35))
		multimesh.set_instance_color(index, stone_dark.lerp(stone_light, rng.randf_range(0.0, 0.75)))
	_add_multimesh("RockField", multimesh)


func _build_logs(rng: RandomNumberGenerator) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.18
	mesh.bottom_radius = 0.28
	mesh.height = 3.6
	mesh.radial_segments = 6
	mesh.material = _material(bark_color, true)
	var multimesh := _multimesh(mesh, log_count, true)
	for index in log_count:
		var point := _sample_position(rng, true)
		var size := rng.randf_range(0.55, 1.2)
		var basis := Basis.from_euler(Vector3(0, rng.randf_range(0.0, TAU), PI * 0.5)).scaled(Vector3(size, size, size))
		multimesh.set_instance_transform(index, Transform3D(basis, point + Vector3.UP * 0.27 * size))
		multimesh.set_instance_color(index, bark_color.lerp(Color(0.28, 0.11, 0.035), rng.randf_range(0.0, 0.55)))
	_add_multimesh("FallenLogs", multimesh)


func _build_distant_ridges(rng: RandomNumberGenerator) -> void:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(5.5, 8.0, 4.0)
	mesh.material = _material(stone_dark.darkened(0.25), true)
	var count := distant_ridge_count
	var multimesh := _multimesh(mesh, count, true)
	for index in count:
		var angle := TAU * float(index) / float(count) + rng.randf_range(-0.12, 0.12)
		var radius := minf(area_size.x, area_size.y) * rng.randf_range(0.43, 0.56)
		var point := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		var size := rng.randf_range(0.7, 1.8)
		var basis := Basis(Vector3.UP, -angle).scaled(Vector3(size, size * rng.randf_range(0.7, 1.6), size))
		multimesh.set_instance_transform(index, Transform3D(basis, point + Vector3.UP * 3.2 * size))
		multimesh.set_instance_color(index, stone_dark.darkened(rng.randf_range(0.18, 0.42)))
	_add_multimesh("DistantRidges", multimesh)


func _sample_position(rng: RandomNumberGenerator, keep_off_trail: bool) -> Vector3:
	for _attempt in 32:
		var point := Vector3(rng.randf_range(-area_size.x * 0.5, area_size.x * 0.5), 0.0, rng.randf_range(-area_size.y * 0.5, area_size.y * 0.5))
		if point.length() < landmark_clear_radius:
			continue
		if keep_off_trail and absf(point.x) < trail_half_width:
			continue
		return point
	return Vector3(area_size.x * 0.42, 0, area_size.y * 0.42)


func _material(color: Color, use_vertex_color: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE if use_vertex_color else color
	material.roughness = 0.92
	material.vertex_color_use_as_albedo = use_vertex_color
	return material


func _multimesh(mesh: Mesh, count: int, colors: bool) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = colors
	multimesh.mesh = mesh
	multimesh.instance_count = count
	return multimesh


func _add_multimesh(name_value: String, multimesh: MultiMesh) -> void:
	var instance := MultiMeshInstance3D.new()
	instance.name = name_value
	instance.multimesh = multimesh
	instance.visibility_range_end = 75.0
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_add_generated(instance)


func _add_generated(node: Node) -> void:
	node.set_meta(&"generated_biome_dressing", true)
	add_child(node)
