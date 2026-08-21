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


static func create_conifer_crown_windformed() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# An asymmetric high-altitude cedar: the prevailing wind leaves one heavy side
	# and a visible bare shoulder instead of another perfect Christmas-tree cone.
	var centers := [Vector3(0.0, 0.0, 0.0), Vector3(0.34, 1.0, -0.08), Vector3(0.62, 1.95, -0.16)]
	var radii := [1.65, 1.28, 0.82]
	for layer: int in centers.size():
		var center: Vector3 = centers[layer]
		var radius: float = radii[layer]
		for side: int in 8:
			var next := (side + 1) % 8
			var angle_a := TAU * float(side) / 8.0 + 0.2 * float(layer)
			var angle_b := TAU * float(next) / 8.0 + 0.2 * float(layer)
			var compression_a := 0.54 if cos(angle_a) < -0.25 else 1.0
			var compression_b := 0.54 if cos(angle_b) < -0.25 else 1.0
			var a := center + Vector3(cos(angle_a) * radius * compression_a, 0.0, sin(angle_a) * radius)
			var b := center + Vector3(cos(angle_b) * radius * compression_b, 0.0, sin(angle_b) * radius)
			var tip := center + Vector3(0.34, 0.68 if layer < 2 else 0.9, 0.0)
			_add_triangle(surface, a, b, tip)
			_add_triangle(surface, b, a, center + Vector3.UP * 0.06)
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


static func create_fungus_cap_bell() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := [Vector2(0.0, 0.34), Vector2(0.38, 0.78), Vector2(0.86, 1.18), Vector2(1.42, 0.72)]
	for ring_index: int in rings.size() - 1:
		var lower: Vector2 = rings[ring_index]
		var upper: Vector2 = rings[ring_index + 1]
		for side: int in 10:
			var next := (side + 1) % 10
			var angle_a := TAU * float(side) / 10.0
			var angle_b := TAU * float(next) / 10.0
			var a := Vector3(cos(angle_a) * lower.y, lower.x, sin(angle_a) * lower.y)
			var b := Vector3(cos(angle_b) * lower.y, lower.x, sin(angle_b) * lower.y)
			var c := Vector3(cos(angle_a) * upper.y, upper.x, sin(angle_a) * upper.y)
			var d := Vector3(cos(angle_b) * upper.y, upper.x, sin(angle_b) * upper.y)
			_add_triangle(surface, a, b, c)
			_add_triangle(surface, b, d, c)
	surface.generate_normals()
	return surface.commit()


static func create_granite_boulder() -> ArrayMesh:
	return _create_tapered_form(1.55, 1.0, 0.42, 7, 2, 0.28, 2.41)


static func create_karst_rib() -> ArrayMesh:
	return _create_tapered_form(3.5, 0.72, 0.08, 6, 4, 0.42, 0.83)


static func create_antler_crown() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var branches := [
		[Vector3(0, 0, 0), Vector3(-0.9, 1.2, 0.1), 0.16, 0.08],
		[Vector3(0, 0.25, 0), Vector3(1.0, 1.55, -0.15), 0.18, 0.07],
		[Vector3(-0.62, 0.82, 0.08), Vector3(-1.35, 1.55, 0.32), 0.1, 0.035],
		[Vector3(-0.58, 0.86, 0.08), Vector3(-0.38, 1.85, -0.22), 0.09, 0.03],
		[Vector3(0.66, 1.02, -0.1), Vector3(1.48, 1.72, -0.38), 0.1, 0.03],
		[Vector3(0.65, 1.02, -0.1), Vector3(0.48, 2.2, 0.2), 0.1, 0.025],
	]
	for branch: Array in branches:
		_add_tube_segment(surface, branch[0], branch[1], branch[2], branch[3], 5)
	surface.generate_normals()
	return surface.commit()


static func create_antler_crown_swept() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spine := [Vector3(0, 0, 0), Vector3(0.28, 0.85, 0.08), Vector3(0.72, 1.65, -0.06), Vector3(1.22, 2.35, 0.16)]
	for index: int in spine.size() - 1:
		_add_tube_segment(surface, spine[index], spine[index + 1], 0.17 - index * 0.035, 0.12 - index * 0.03, 5)
	_add_tube_segment(surface, spine[1], Vector3(-0.72, 1.45, 0.42), 0.11, 0.025, 5)
	_add_tube_segment(surface, spine[2], Vector3(0.15, 2.45, -0.38), 0.09, 0.022, 5)
	_add_tube_segment(surface, spine[2], Vector3(1.5, 2.15, 0.5), 0.08, 0.018, 5)
	surface.generate_normals()
	return surface.commit()


static func create_false_beast_echo() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A low-poly running animal readable at a distance: long torso, lowered head,
	# four broken legs and two antler strokes. It deliberately has no closed feet.
	_add_tube_segment(surface, Vector3(-0.72, 0.52, 0), Vector3(0.48, 0.58, 0), 0.34, 0.24, 6)
	_add_tube_segment(surface, Vector3(0.38, 0.61, 0), Vector3(0.86, 0.78, 0), 0.25, 0.14, 5)
	_add_tube_segment(surface, Vector3(-0.48, 0.38, -0.18), Vector3(-0.72, -0.18, -0.3), 0.09, 0.025, 4)
	_add_tube_segment(surface, Vector3(-0.2, 0.38, 0.18), Vector3(-0.05, -0.2, 0.34), 0.09, 0.025, 4)
	_add_tube_segment(surface, Vector3(0.24, 0.42, -0.17), Vector3(0.48, -0.18, -0.28), 0.08, 0.02, 4)
	_add_tube_segment(surface, Vector3(0.48, 0.45, 0.16), Vector3(0.72, -0.16, 0.3), 0.08, 0.02, 4)
	_add_tube_segment(surface, Vector3(0.72, 0.88, -0.08), Vector3(0.92, 1.22, -0.28), 0.055, 0.018, 4)
	_add_tube_segment(surface, Vector3(0.72, 0.88, 0.08), Vector3(0.94, 1.18, 0.31), 0.055, 0.018, 4)
	surface.generate_normals()
	return surface.commit()


static func create_crystal_cluster() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_crystal(surface, Vector3(-0.55, 0, 0.25), 0.48, 2.25, 0.3)
	_add_crystal(surface, Vector3(0.1, 0, 0.0), 0.62, 3.4, -0.2)
	_add_crystal(surface, Vector3(0.62, 0, -0.2), 0.38, 1.8, 0.12)
	_add_crystal(surface, Vector3(0.15, 0, 0.55), 0.3, 1.35, -0.45)
	surface.generate_normals()
	return surface.commit()


static func create_ice_lattice() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_tube_segment(surface, Vector3(-1.0, 0, 0), Vector3(0.0, 2.35, 0.12), 0.18, 0.09, 5)
	_add_tube_segment(surface, Vector3(1.0, 0, 0), Vector3(0.0, 2.35, 0.12), 0.18, 0.09, 5)
	_add_crystal(surface, Vector3(-0.62, 0, 0.18), 0.22, 1.2, -0.4)
	_add_crystal(surface, Vector3(0.66, 0, -0.16), 0.2, 1.05, 0.45)
	surface.generate_normals()
	return surface.commit()


static func create_burnt_crown() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_tube_segment(surface, Vector3(0, 0, 0), Vector3(-0.8, 1.45, 0.12), 0.18, 0.035, 5)
	_add_tube_segment(surface, Vector3(0.0, 0.12, 0), Vector3(0.72, 1.02, -0.38), 0.15, 0.03, 5)
	_add_tube_segment(surface, Vector3(-0.34, 0.65, 0.05), Vector3(-1.0, 0.98, -0.28), 0.09, 0.02, 4)
	surface.generate_normals()
	return surface.commit()


static func create_burnt_crown_fork() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_tube_segment(surface, Vector3(0, 0, 0), Vector3(0.05, 1.0, 0), 0.2, 0.13, 6)
	_add_tube_segment(surface, Vector3(0.05, 0.88, 0), Vector3(-0.86, 2.0, 0.22), 0.13, 0.025, 5)
	_add_tube_segment(surface, Vector3(0.05, 0.88, 0), Vector3(0.74, 2.34, -0.32), 0.12, 0.02, 5)
	_add_tube_segment(surface, Vector3(-0.45, 1.46, 0.1), Vector3(-1.12, 1.72, -0.24), 0.07, 0.015, 4)
	surface.generate_normals()
	return surface.commit()


static func create_reed_head() -> ArrayMesh:
	return _create_tapered_form(0.86, 0.12, 0.055, 6, 3, 0.06, 1.7)


static func create_reed_fan() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in 5:
		var x := float(index - 2) * 0.21
		var height := 0.9 + float(index % 3) * 0.3
		_add_tube_segment(surface, Vector3(x * 0.3, 0, 0), Vector3(x, height, 0.08 * sin(index)), 0.055, 0.018, 5)
	surface.generate_normals()
	return surface.commit()


static func create_root_loop() -> ArrayMesh:
	return _create_loop_form(Vector2(0.95, 1.35), 0.14, 11, 0.32)


static func create_root_spire() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_tube_segment(surface, Vector3(-0.65, 0, 0), Vector3(-0.2, 1.4, 0.32), 0.23, 0.12, 6)
	_add_tube_segment(surface, Vector3(0.66, 0, 0.1), Vector3(-0.2, 1.4, 0.32), 0.2, 0.1, 6)
	_add_tube_segment(surface, Vector3(-0.2, 1.4, 0.32), Vector3(0.24, 2.8, -0.16), 0.13, 0.025, 6)
	surface.generate_normals()
	return surface.commit()


static func create_heart_loop() -> ArrayMesh:
	return _create_loop_form(Vector2(1.35, 1.58), 0.11, 13, 0.58)


static func create_heart_branch() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_tube_segment(surface, Vector3(0, 0, 0), Vector3(0, 1.45, 0), 0.14, 0.09, 6)
	_add_tube_segment(surface, Vector3(0, 1.0, 0), Vector3(-1.15, 2.2, 0.3), 0.1, 0.02, 5)
	_add_tube_segment(surface, Vector3(0, 1.0, 0), Vector3(1.15, 2.2, -0.3), 0.1, 0.02, 5)
	_add_tube_segment(surface, Vector3(-0.74, 1.76, 0.2), Vector3(-0.05, 2.72, 0), 0.055, 0.018, 5)
	_add_tube_segment(surface, Vector3(0.74, 1.76, -0.2), Vector3(0.05, 2.72, 0), 0.055, 0.018, 5)
	surface.generate_normals()
	return surface.commit()


static func create_red_scree() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_crystal(surface, Vector3(-0.5, 0, 0.2), 0.9, 1.2, 0.8)
	_add_crystal(surface, Vector3(0.45, 0, -0.25), 0.7, 0.82, -0.7)
	_add_crystal(surface, Vector3(0.0, 0, 0.5), 0.5, 0.65, 0.15)
	surface.generate_normals()
	return surface.commit()


static func create_granite_slab() -> ArrayMesh:
	return _create_tapered_form(1.2, 1.35, 0.78, 6, 2, 0.12, 0.91)


static func create_karst_stack() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_irregular_disc(surface, 1.05, 0.0, 7, 0.2)
	_add_irregular_disc(surface, 0.82, 0.72, 7, 0.9)
	_add_irregular_disc(surface, 0.58, 1.46, 6, 1.7)
	_add_crystal(surface, Vector3(0.12, 1.46, 0), 0.31, 1.2, 0.24)
	surface.generate_normals()
	return surface.commit()


static func create_red_monolith() -> ArrayMesh:
	return _create_tapered_form(2.45, 0.72, 0.12, 5, 3, 0.32, 1.85)


static func create_ice_geology() -> ArrayMesh:
	return create_crystal_cluster()


static func create_ice_arch() -> ArrayMesh:
	return _create_loop_form(Vector2(1.2, 1.6), 0.22, 10, 0.12)


static func create_ash_column() -> ArrayMesh:
	return _create_tapered_form(3.1, 0.78, 0.22, 5, 3, 0.14, 2.2)


static func create_ash_cairn() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer: int in 4:
		_add_irregular_disc(surface, 1.0 - float(layer) * 0.17, float(layer) * 0.42, 6, float(layer) * 1.1)
	surface.generate_normals()
	return surface.commit()


static func create_wetland_shelf() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_irregular_disc(surface, 1.45, 0.0, 9, 0.17)
	_add_irregular_disc(surface, 1.0, 0.28, 8, 0.31)
	_add_irregular_disc(surface, 0.58, 0.52, 7, 0.48)
	surface.generate_normals()
	return surface.commit()


static func create_wetland_stone() -> ArrayMesh:
	return _create_tapered_form(0.72, 1.25, 0.82, 8, 2, 0.08, 2.7)


static func create_root_nodule() -> ArrayMesh:
	return _create_tapered_form(1.8, 1.15, 0.32, 8, 3, 0.5, 1.26)


static func create_root_bulb_cluster() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_crystal(surface, Vector3(-0.48, 0, 0.16), 0.66, 1.42, -0.8)
	_add_crystal(surface, Vector3(0.42, 0, -0.2), 0.75, 1.68, 0.7)
	_add_tube_segment(surface, Vector3(-0.6, 0.2, 0), Vector3(0.64, 0.16, 0.12), 0.22, 0.18, 6)
	surface.generate_normals()
	return surface.commit()


static func create_floating_strata() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in 3:
		var y := float(layer) * 0.48
		var radius := 1.3 - float(layer) * 0.22
		_add_irregular_disc(surface, radius, y, 7, float(layer) * 0.7)
	surface.generate_normals()
	return surface.commit()


static func create_floating_shard() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_crystal(surface, Vector3.ZERO, 1.05, 2.25, 0.34)
	_add_irregular_disc(surface, 1.34, 0.42, 7, 0.8)
	surface.generate_normals()
	return surface.commit()


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


static func create_ecology_groundcover(ecology: int) -> ArrayMesh:
	if ecology == 0:
		return create_ground_clump(false)
	if ecology == 1:
		return create_ground_clump(true)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	match ecology:
		2: # Crimson thorn grass.
			for index in 6:
				var angle := TAU * float(index) / 6.0
				var base := Vector3(cos(angle), 0, sin(angle)) * 0.12
				_add_triangle(surface, base + Vector3(-0.07, 0, 0), base + Vector3(0.07, 0, 0), base + Vector3(cos(angle) * 0.48, 0.75 + 0.14 * (index % 2), sin(angle) * 0.48))
		3: # Ice rosette.
			for index in 5:
				var angle := TAU * float(index) / 5.0
				_add_crystal(surface, Vector3(cos(angle), 0, sin(angle)) * 0.16, 0.12, 0.52 + 0.1 * index, angle)
		4: # Burnt heath.
			for index in 5:
				var x := -0.35 + float(index) * 0.17
				_add_tube_segment(surface, Vector3(x, 0, 0), Vector3(x + 0.08 * sin(index), 0.28 + 0.08 * (index % 3), 0.1 * cos(index)), 0.025, 0.008, 4)
		5: # Reed fan.
			for index in 7:
				var x := -0.42 + float(index) * 0.14
				_add_tube_segment(surface, Vector3(x, 0, 0), Vector3(x + 0.08 * sin(index), 0.8 + 0.12 * (index % 3), 0.12 * cos(index)), 0.018, 0.009, 4)
		6: # Root tendrils.
			for index in 5:
				var angle := TAU * float(index) / 5.0
				_add_tube_segment(surface, Vector3.ZERO, Vector3(cos(angle) * 0.72, 0.18 + 0.08 * (index % 2), sin(angle) * 0.72), 0.06, 0.018, 5)
		_: # Concordant ring flowers.
			for index in 4:
				var angle := TAU * float(index) / 4.0
				_add_tube_segment(surface, Vector3(cos(angle) * 0.18, 0, sin(angle) * 0.18), Vector3(cos(angle) * 0.32, 0.5, sin(angle) * 0.32), 0.035, 0.014, 5)
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


static func _create_loop_form(extents: Vector2, tube_radius: float, segments: int, wobble: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in segments:
		var angle_a := TAU * float(index) / float(segments)
		var angle_b := TAU * float(index + 1) / float(segments)
		var a := Vector3(cos(angle_a) * extents.x, sin(angle_a) * extents.y, sin(angle_a * 3.0) * wobble)
		var b := Vector3(cos(angle_b) * extents.x, sin(angle_b) * extents.y, sin(angle_b * 3.0) * wobble)
		_add_tube_segment(surface, a, b, tube_radius, tube_radius * (0.86 + 0.14 * sin(angle_b * 2.0)), 6)
	surface.generate_normals()
	return surface.commit()


static func _add_tube_segment(surface: SurfaceTool, start: Vector3, end: Vector3, radius_start: float, radius_end: float, sides: int) -> void:
	var direction := (end - start).normalized()
	var right := direction.cross(Vector3.UP)
	if right.length_squared() < 0.01:
		right = direction.cross(Vector3.RIGHT)
	right = right.normalized()
	var up := right.cross(direction).normalized()
	for side in sides:
		var next := (side + 1) % sides
		var angle_a := TAU * float(side) / float(sides)
		var angle_b := TAU * float(next) / float(sides)
		var radial_a := right * cos(angle_a) + up * sin(angle_a)
		var radial_b := right * cos(angle_b) + up * sin(angle_b)
		var a := start + radial_a * radius_start
		var b := start + radial_b * radius_start
		var c := end + radial_a * radius_end
		var d := end + radial_b * radius_end
		_add_triangle(surface, a, b, c)
		_add_triangle(surface, b, d, c)


static func _add_crystal(surface: SurfaceTool, center: Vector3, radius: float, height: float, lean: float) -> void:
	var tip := center + Vector3(sin(lean) * height * 0.18, height, cos(lean) * height * 0.12)
	for side in 5:
		var next := (side + 1) % 5
		var angle_a := TAU * float(side) / 5.0
		var angle_b := TAU * float(next) / 5.0
		var a := center + Vector3(cos(angle_a) * radius, 0, sin(angle_a) * radius)
		var b := center + Vector3(cos(angle_b) * radius, 0, sin(angle_b) * radius)
		_add_triangle(surface, a, b, tip)
		_add_triangle(surface, b, a, center + Vector3.UP * 0.04)


static func _add_irregular_disc(surface: SurfaceTool, radius: float, height: float, sides: int, phase: float) -> void:
	var center := Vector3(0, height, 0)
	for side in sides:
		var next := (side + 1) % sides
		var angle_a := TAU * float(side) / float(sides)
		var angle_b := TAU * float(next) / float(sides)
		var radius_a := radius * (0.82 + 0.18 * sin(float(side) * 2.3 + phase))
		var radius_b := radius * (0.82 + 0.18 * sin(float(next) * 2.3 + phase))
		var a := Vector3(cos(angle_a) * radius_a, height, sin(angle_a) * radius_a)
		var b := Vector3(cos(angle_b) * radius_b, height, sin(angle_b) * radius_b)
		_add_triangle(surface, a, b, center + Vector3.UP * 0.06)


static func _add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
