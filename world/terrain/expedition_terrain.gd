class_name ExpeditionTerrain
extends StaticBody3D

@export var origin: Vector2 = Vector2(-13, 6)
@export var size: Vector2 = Vector2(57, 49)
@export_range(17, 129, 2) var resolution: int = 65
@export var base_seed: int = 61937

var _run_seed: int = 0
var _noise := FastNoiseLite.new()
var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D


func _ready() -> void:
	add_to_group(&"terrain_height_provider")
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "LandscapeMesh"
	add_child(_mesh_instance)
	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "LandscapeCollision"
	add_child(_collision_shape)
	_rebuild()


func set_run_seed(value: int) -> void:
	if _run_seed == value:
		return
	_run_seed = value
	_rebuild()


func get_height_at_global(world_position: Vector3) -> float:
	return _height_at(world_position.x, world_position.z)


func _rebuild() -> void:
	if _mesh_instance == null or _collision_shape == null:
		return
	_noise.seed = base_seed * 1000003 + _run_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.038
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 4
	_noise.fractal_lacunarity = 2.05
	_noise.fractal_gain = 0.46
	var mesh := _build_mesh()
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = _build_material()
	_collision_shape.shape = mesh.create_trimesh_shape()


func _build_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var step := size / float(resolution - 1)
	for z_index in resolution:
		for x_index in resolution:
			var x := origin.x + float(x_index) * step.x
			var z := origin.y + float(z_index) * step.y
			var height := _height_at(x, z)
			vertices.append(Vector3(x, height, z))
			var left := _height_at(x - step.x, z)
			var right := _height_at(x + step.x, z)
			var back := _height_at(x, z - step.y)
			var front := _height_at(x, z + step.y)
			var normal := Vector3(left - right, step.x + step.y, back - front).normalized()
			normals.append(normal)
			var slope := 1.0 - normal.y
			var low_color := Color(0.15, 0.23, 0.085)
			var high_color := Color(0.25, 0.29, 0.13)
			var rock_color := Color(0.29, 0.255, 0.19)
			var terrain_color := low_color.lerp(high_color, clampf((height + 0.5) / 4.5, 0.0, 1.0))
			var point := Vector2(x, z)
			var trail_distance := _distance_to_segment(point, Vector2(0, 17), Vector2(0, 49))
			var trail_tint := 1.0 - smoothstep(1.1, 3.0, trail_distance)
			terrain_color = terrain_color.lerp(Color(0.31, 0.205, 0.09), trail_tint * 0.72)
			var grove_tint := 1.0 - smoothstep(9.0, 24.0, point.distance_to(Vector2(27, 17)))
			terrain_color = terrain_color.lerp(Color(0.105, 0.245, 0.18), grove_tint * 0.42)
			var camp_tint := 1.0 - smoothstep(4.0, 9.0, point.distance_to(Vector2(31.5, 20.5)))
			terrain_color = terrain_color.lerp(Color(0.31, 0.22, 0.105), camp_tint * 0.4)
			var color_variation := _noise.get_noise_2d(x * 3.7 + 140.0, z * 3.7 - 80.0) * 0.08
			terrain_color = terrain_color.lightened(maxf(color_variation, 0.0)).darkened(maxf(-color_variation, 0.0))
			colors.append(terrain_color.lerp(rock_color, smoothstep(0.12, 0.42, slope)))
			uvs.append(Vector2(float(x_index), float(z_index)) / 8.0)
	for z_index in resolution - 1:
		for x_index in resolution - 1:
			var current := z_index * resolution + x_index
			indices.append_array(PackedInt32Array([
				current,
				current + resolution,
				current + 1,
				current + 1,
				current + resolution,
				current + resolution + 1,
			]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _height_at(x: float, z: float) -> float:
	var noise_height := _noise.get_noise_2d(x, z) * 1.15
	noise_height += _noise.get_noise_2d(x * 0.37 + 91.0, z * 0.37 - 47.0) * 0.7
	var edge_distance := minf(minf(x - origin.x, origin.x + size.x - x), minf(z - origin.y, origin.y + size.y - z))
	var edge_rise := pow(clampf(1.0 - edge_distance / 10.0, 0.0, 1.0), 2.0) * 4.5
	var height := noise_height + edge_rise
	height = _blend_disc(height, x, z, Vector2(0, 15), 10.0, 0.0)
	height = _blend_corridor(height, x, z, Vector2(0, 18), Vector2(0, 48), 4.2, 0.0, 0.25)
	height = _blend_disc(height, x, z, Vector2(25, 15), 13.5, 0.05)
	var camp_center := Vector2(31.5, 20.5)
	var camp_distance := Vector2(x, z).distance_to(camp_center)
	var camp_blend := 1.0 - smoothstep(4.6, 10.5, camp_distance)
	height = lerpf(height, 1.58, camp_blend)
	var ramp_start := Vector2(20.5, 17.0)
	var ramp_end := Vector2(29.5, 20.0)
	var ramp_t := _segment_progress(Vector2(x, z), ramp_start, ramp_end)
	var ramp_distance := _distance_to_segment(Vector2(x, z), ramp_start, ramp_end)
	var ramp_blend := 1.0 - smoothstep(2.1, 4.2, ramp_distance)
	height = lerpf(height, lerpf(0.08, 1.5, ramp_t), ramp_blend)
	return height


func _blend_disc(current: float, x: float, z: float, center: Vector2, radius: float, target: float) -> float:
	var distance := Vector2(x, z).distance_to(center)
	var blend := 1.0 - smoothstep(radius * 0.58, radius, distance)
	return lerpf(current, target, blend)


func _blend_corridor(current: float, x: float, z: float, start: Vector2, end: Vector2, width: float, start_height: float, end_height: float) -> float:
	var point := Vector2(x, z)
	var distance := _distance_to_segment(point, start, end)
	var progress := _segment_progress(point, start, end)
	var blend := 1.0 - smoothstep(width * 0.55, width, distance)
	return lerpf(current, lerpf(start_height, end_height, progress), blend)


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var t := clampf((point - start).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
	return point.distance_to(start + segment * t)


func _segment_progress(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	return clampf((point - start).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)


func _build_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.96
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
