class_name BiomeMeshLibrary
extends RefCounted


static func create_taiga_trunk() -> ArrayMesh:
	return _create_tapered_form(5.8, 0.42, 0.15, 8, 4, 0.16, 0.37)


static func create_conifer_crown() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var layer_data := [
		Vector3(0.0, 0.0, 1.7),
		Vector3(0.0, 1.15, 1.48),
		Vector3(0.0, 2.2, 1.12),
		Vector3(0.0, 3.1, 0.72),
	]
	for layer_index in layer_data.size():
		var data: Vector3 = layer_data[layer_index]
		var center_y := data.y
		var radius := data.z
		var thickness := 0.72 if layer_index < 2 else 0.58
		var phase := float(layer_index) * 0.41
		for side in 9:
			var next := (side + 1) % 9
			var angle_a := TAU * float(side) / 9.0 + phase
			var angle_b := TAU * float(next) / 9.0 + phase
			var radius_a := radius * (0.86 + 0.16 * sin(float(side) * 2.7 + phase))
			var radius_b := radius * (0.86 + 0.16 * sin(float(next) * 2.7 + phase))
			var edge_a := Vector3(cos(angle_a) * radius_a, center_y, sin(angle_a) * radius_a)
			var edge_b := Vector3(cos(angle_b) * radius_b, center_y, sin(angle_b) * radius_b)
			var upper := Vector3(0.08 * sin(phase), center_y + thickness, 0.06 * cos(phase))
			_add_triangle(surface, edge_a, edge_b, upper)
			_add_triangle(surface, edge_b, edge_a, Vector3(0.0, center_y + 0.08, 0.0))
	surface.generate_normals()
	return surface.commit()


static func create_fungus_stem() -> ArrayMesh:
	return _create_tapered_form(5.4, 0.52, 0.34, 9, 5, 0.28, 1.13)


static func create_fungus_cap() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := [
		Vector2(0.0, 1.55),
		Vector2(0.28, 1.92),
		Vector2(0.66, 1.5),
		Vector2(0.98, 0.76),
		Vector2(1.14, 0.12),
	]
	var sides := 12
	for ring_index in rings.size() - 1:
		var lower: Vector2 = rings[ring_index]
		var upper: Vector2 = rings[ring_index + 1]
		for side in sides:
			var next := (side + 1) % sides
			var angle_a := TAU * float(side) / float(sides)
			var angle_b := TAU * float(next) / float(sides)
			var wobble_a := 0.92 + 0.08 * sin(float(side) * 4.1)
			var wobble_b := 0.92 + 0.08 * sin(float(next) * 4.1)
			var a := Vector3(cos(angle_a) * lower.y * wobble_a, lower.x, sin(angle_a) * lower.y * wobble_a)
			var b := Vector3(cos(angle_b) * lower.y * wobble_b, lower.x, sin(angle_b) * lower.y * wobble_b)
			var c := Vector3(cos(angle_a) * upper.y, upper.x, sin(angle_a) * upper.y)
			var d := Vector3(cos(angle_b) * upper.y, upper.x, sin(angle_b) * upper.y)
			_add_triangle(surface, a, b, c)
			_add_triangle(surface, b, d, c)
			# Pale radial underside gives the cap a readable mushroom silhouette from below.
			if ring_index == 0:
				_add_triangle(surface, b, a, Vector3(0.0, 0.16, 0.0))
	surface.generate_normals()
	return surface.commit()


static func create_granite_boulder() -> ArrayMesh:
	return _create_tapered_form(1.55, 1.0, 0.42, 7, 2, 0.28, 2.41)


static func create_karst_rib() -> ArrayMesh:
	return _create_tapered_form(3.5, 0.72, 0.08, 6, 4, 0.42, 0.83)


static func create_ground_clump(fungal: bool = false) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blade_count := 7 if not fungal else 5
	for index in blade_count:
		var angle := TAU * float(index) / float(blade_count)
		var radial := 0.1 + float(index % 3) * 0.08
		var base := Vector3(cos(angle) * radial, 0.0, sin(angle) * radial)
		var side := Vector3(cos(angle + PI * 0.5), 0.0, sin(angle + PI * 0.5)) * (0.08 if fungal else 0.055)
		var lean := Vector3(cos(angle), 0.0, sin(angle)) * (0.24 if fungal else 0.17)
		var height := (0.38 + float(index % 4) * 0.13) if not fungal else (0.22 + float(index % 3) * 0.11)
		_add_triangle(surface, base - side, base + side, base + lean + Vector3.UP * height)
		if fungal:
			var cap_center := base + lean + Vector3.UP * height
			_add_triangle(surface, cap_center + Vector3(-0.16, 0.0, -0.05), cap_center + Vector3(0.16, 0.0, -0.05), cap_center + Vector3(0.0, 0.08, 0.13))
	surface.generate_normals()
	return surface.commit()


static func _create_tapered_form(height: float, bottom_radius: float, top_radius: float, sides: int, segments: int, bend: float, phase: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in segments:
		var t0 := float(segment) / float(segments)
		var t1 := float(segment + 1) / float(segments)
		var y0 := height * t0
		var y1 := height * t1
		var center0 := Vector3(sin(t0 * 3.4 + phase) * bend * t0, y0, cos(t0 * 2.8 + phase) * bend * t0)
		var center1 := Vector3(sin(t1 * 3.4 + phase) * bend * t1, y1, cos(t1 * 2.8 + phase) * bend * t1)
		var radius0 := lerpf(bottom_radius, top_radius, t0) * (0.9 + 0.1 * sin(float(segment) * 2.2 + phase))
		var radius1 := lerpf(bottom_radius, top_radius, t1)
		for side in sides:
			var next := (side + 1) % sides
			var angle_a := TAU * float(side) / float(sides)
			var angle_b := TAU * float(next) / float(sides)
			var a := center0 + Vector3(cos(angle_a) * radius0, 0.0, sin(angle_a) * radius0)
			var b := center0 + Vector3(cos(angle_b) * radius0, 0.0, sin(angle_b) * radius0)
			var c := center1 + Vector3(cos(angle_a) * radius1, 0.0, sin(angle_a) * radius1)
			var d := center1 + Vector3(cos(angle_b) * radius1, 0.0, sin(angle_b) * radius1)
			_add_triangle(surface, a, b, c)
			_add_triangle(surface, b, d, c)
	surface.generate_normals()
	return surface.commit()


static func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
