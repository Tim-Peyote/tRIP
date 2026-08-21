class_name TerrainChunkMeshBuilder
extends RefCounted


static func build(
	coordinate: Vector2i,
	chunk_size: float,
	resolution: int,
	minimum_world_z: float,
	height_sampler: Callable,
	color_sampler: Callable
) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var step := chunk_size / float(resolution - 1)
	var start_x := float(coordinate.x) * chunk_size
	var start_z := float(coordinate.y) * chunk_size
	var sample_resolution := resolution + 2
	var heights := PackedFloat32Array()
	heights.resize(sample_resolution * sample_resolution)

	# Sample one shared border around the chunk. The old implementation called the
	# terrain function five times per vertex, repeatedly evaluating the same noise.
	for sample_z in sample_resolution:
		for sample_x in sample_resolution:
			var world_x := start_x + float(sample_x - 1) * step
			var world_z := start_z + float(sample_z - 1) * step
			heights[sample_z * sample_resolution + sample_x] = float(height_sampler.call(world_x, world_z))

	vertices.resize(resolution * resolution)
	normals.resize(resolution * resolution)
	colors.resize(resolution * resolution)
	for z_index in resolution:
		for x_index in resolution:
			var sample_index := (z_index + 1) * sample_resolution + x_index + 1
			var vertex_index := z_index * resolution + x_index
			var x := start_x + float(x_index) * step
			var z := start_z + float(z_index) * step
			var height := heights[sample_index]
			var left := heights[sample_index - 1]
			var right := heights[sample_index + 1]
			var back := heights[sample_index - sample_resolution]
			var front := heights[sample_index + sample_resolution]
			var normal := Vector3(left - right, step * 2.0, back - front).normalized()
			vertices[vertex_index] = Vector3(x, height, z)
			normals[vertex_index] = normal
			colors[vertex_index] = color_sampler.call(Vector2(x, z), height, 1.0 - normal.y) as Color

	for z_index in resolution - 1:
		for x_index in resolution - 1:
			var world_z := start_z + float(z_index) * step
			if world_z < minimum_world_z:
				continue
			var current := z_index * resolution + x_index
			indices.append_array(PackedInt32Array([
				current,
				current + resolution,
				current + 1,
				current + 1,
				current + resolution,
				current + resolution + 1,
			]))

	var mesh := ArrayMesh.new()
	if indices.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
