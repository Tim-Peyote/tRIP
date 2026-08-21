class_name ExpeditionTerrain
extends StaticBody3D

const PHASE_ORDINARY: StringName = &"ordinary"
const PHASE_MYCELIAL: StringName = &"mycelial"
const MIN_EXPEDITION_Z: float = 5.8

@export_range(16.0, 64.0, 1.0) var chunk_size: float = 30.0
@export_range(9, 49, 2) var chunk_resolution: int = 25
@export_range(1, 4, 1) var active_radius: int = 2
@export_range(1, 4, 1) var chunks_per_frame: int = 1
@export var base_seed: int = 61937

var _run_seed: int = 0
var _world_phase: StringName = PHASE_ORDINARY
var _phase_definition: WorldPhaseDefinition
var _phase_amount: float = 0.0
var _target: Node3D
var _last_center := Vector2i(999999, 999999)
var _chunks: Dictionary[Vector2i, StaticBody3D] = {}
var _pending: Array[Vector2i] = []
var _noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _terrain_material: ShaderMaterial


func _ready() -> void:
	add_to_group(&"terrain_height_provider")
	_configure_noise()
	_terrain_material = _build_terrain_material()
	_refresh_chunks(Vector3(0, 0, 15), true)
	set_process(true)


func setup(target: Node3D) -> void:
	_target = target
	if is_instance_valid(_target):
		_refresh_chunks(_target.global_position, true)


func ensure_area_at(world_position: Vector3) -> void:
	_refresh_chunks(world_position, true)


func set_run_seed(value: int) -> void:
	if _run_seed == value:
		return
	_run_seed = value
	_configure_noise()
	_rebuild_loaded_chunks()


func set_world_phase(value: StringName) -> void:
	if value != PHASE_MYCELIAL:
		value = PHASE_ORDINARY
	if _world_phase == value:
		return
	_world_phase = value
	var tween := create_tween()
	tween.tween_method(_set_phase_amount, _phase_amount, 1.0 if value == PHASE_MYCELIAL else 0.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_rebuild_loaded_decor()


func apply_world_phase(definition: WorldPhaseDefinition) -> void:
	if definition == null:
		return
	var target_clearance := 0.12
	var should_reground_target := is_instance_valid(_target) and _target.global_position.z >= MIN_EXPEDITION_Z
	if should_reground_target:
		target_clearance = maxf(_target.global_position.y - _height_at(_target.global_position.x, _target.global_position.z), 0.12)
	var definition_changed := _phase_definition != definition
	_phase_definition = definition
	var next_phase := PHASE_ORDINARY if definition.is_baseline() else definition.id
	if _world_phase == next_phase and not definition_changed:
		return
	_world_phase = next_phase
	if _terrain_material != null:
		_terrain_material.set_shader_parameter(&"phase_low", definition.stone_low)
		_terrain_material.set_shader_parameter(&"phase_high", definition.beacon_color)
	var tween := create_tween()
	tween.tween_method(_set_phase_amount, _phase_amount, 0.0 if definition.is_baseline() else 1.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if should_reground_target:
		var safe_position := _target.global_position
		safe_position.y = _height_at(safe_position.x, safe_position.z) + target_clearance
		_target.global_position = safe_position
		if _target is CharacterBody3D:
			(_target as CharacterBody3D).velocity.y = 0.0
	_rebuild_world_geometry()


func get_world_phase() -> StringName:
	return _world_phase


func get_loaded_chunk_count() -> int:
	return _chunks.size()


func get_loaded_ecology_signature() -> String:
	var parts := PackedStringArray()
	var pack := _get_content_pack()
	parts.append(pack.get_generation_signature() if pack != null else "unassigned")
	for coordinate: Vector2i in _chunks:
		var body := _chunks[coordinate]
		for child: Node in body.get_children():
			if child.name != "Terrain" and child.name != "Collision":
				parts.append(child.name)
	parts.sort()
	return "|".join(parts)


func get_height_at_global(world_position: Vector3) -> float:
	return _height_at(world_position.x, world_position.z)


func _process(_delta: float) -> void:
	if is_instance_valid(_target):
		var center := _chunk_coordinate(_target.global_position)
		if center != _last_center:
			_refresh_chunks(_target.global_position, true)
	for _index in mini(chunks_per_frame, _pending.size()):
		var coordinate: Vector2i = _pending.pop_front()
		if not _chunks.has(coordinate):
			_build_chunk(coordinate)


func _set_phase_amount(value: float) -> void:
	_phase_amount = value
	if _terrain_material != null:
		_terrain_material.set_shader_parameter(&"metamorphosis", value)


func _configure_noise() -> void:
	_noise.seed = base_seed * 1000003 + _run_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.0075
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 5
	_noise.fractal_lacunarity = 2.08
	_noise.fractal_gain = 0.48
	_detail_noise.seed = _noise.seed + 7919
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail_noise.frequency = 0.035
	_detail_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_detail_noise.fractal_octaves = 3


func _refresh_chunks(world_position: Vector3, immediate_center: bool) -> void:
	var center := _chunk_coordinate(world_position)
	_last_center = center
	var desired: Dictionary[Vector2i, bool] = {}
	var offsets: Array[Vector2i] = []
	for z_offset in range(-active_radius, active_radius + 1):
		for x_offset in range(-active_radius, active_radius + 1):
			offsets.append(Vector2i(x_offset, z_offset))
	offsets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.length_squared() < b.length_squared())
	_pending.clear()
	for offset: Vector2i in offsets:
		var coordinate := center + offset
		desired[coordinate] = true
		if not _chunks.has(coordinate):
			_pending.append(coordinate)
	for coordinate: Vector2i in _chunks.keys():
		if not desired.has(coordinate):
			_chunks[coordinate].queue_free()
			_chunks.erase(coordinate)
	if immediate_center and not _chunks.has(center):
		_pending.erase(center)
		_build_chunk(center)


func _chunk_coordinate(world_position: Vector3) -> Vector2i:
	return Vector2i(floori(world_position.x / chunk_size), floori(world_position.z / chunk_size))


func _build_chunk(coordinate: Vector2i) -> void:
	var body := StaticBody3D.new()
	body.name = "LandscapeChunk_%d_%d" % [coordinate.x, coordinate.y]
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta(&"landscape_chunk", true)
	add_child(body)
	var mesh := _build_chunk_mesh(coordinate)
	if mesh.get_surface_count() > 0:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Terrain"
		mesh_instance.mesh = mesh
		mesh_instance.material_override = _terrain_material
		body.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		collision.shape = mesh.create_trimesh_shape()
		body.add_child(collision)
	_build_chunk_decor(body, coordinate)
	_chunks[coordinate] = body


func _build_chunk_mesh(coordinate: Vector2i) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var step := chunk_size / float(chunk_resolution - 1)
	var start_x := float(coordinate.x) * chunk_size
	var start_z := float(coordinate.y) * chunk_size
	for z_index in chunk_resolution:
		for x_index in chunk_resolution:
			var x := start_x + float(x_index) * step
			var z := start_z + float(z_index) * step
			var height := _height_at(x, z)
			vertices.append(Vector3(x, height, z))
			var left := _height_at(x - step, z)
			var right := _height_at(x + step, z)
			var back := _height_at(x, z - step)
			var front := _height_at(x, z + step)
			var normal := Vector3(left - right, step * 2.0, back - front).normalized()
			normals.append(normal)
			colors.append(_terrain_color(Vector2(x, z), height, 1.0 - normal.y))
	for z_index in chunk_resolution - 1:
		for x_index in chunk_resolution - 1:
			var world_z := start_z + float(z_index) * step
			if world_z < MIN_EXPEDITION_Z:
				continue
			var current := z_index * chunk_resolution + x_index
			indices.append_array(PackedInt32Array([current, current + chunk_resolution, current + 1, current + 1, current + chunk_resolution, current + chunk_resolution + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if not indices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _height_at(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var pack := _get_content_pack()
	var elevation_scale := pack.elevation_scale if pack != null else 1.0
	var ridge_bias := pack.ridge_bias if pack != null else 0.25
	var macro := _noise.get_noise_2d(x, z) * 11.0 * elevation_scale
	var ridges := absf(_detail_noise.get_noise_2d(x * 0.42 + 90.0, z * 0.42 - 40.0)) * lerpf(2.4, 8.2, ridge_bias)
	var height := macro + ridges - 1.5
	if pack != null:
		match pack.ecology_family:
			BiomeContentPack.EcologyFamily.MYCELIAL_KARST:
				var karst := maxf(_detail_noise.get_noise_2d(x * 0.7 - 130.0, z * 0.7 + 80.0), 0.0)
				height -= karst * karst * 7.5 * pack.basin_bias
				height += sin(x * 0.085 + z * 0.04) * 0.7
			BiomeContentPack.EcologyFamily.CRIMSON_STEPPE:
				height += absf(sin(x * 0.052) + cos(z * 0.047)) * 2.6
				height = floorf(height * 0.48) / 0.48 + _detail_noise.get_noise_2d(x, z) * 0.35
			BiomeContentPack.EcologyFamily.GLACIAL_CIRQUE:
				height += absf(_noise.get_noise_2d(x * 0.55, z * 0.55)) * 5.5
				height = floorf(height * 0.34) / 0.34
			BiomeContentPack.EcologyFamily.ASHEN_TUNDRA:
				height = lerpf(height, _noise.get_noise_2d(x * 0.35, z * 0.35) * 5.5, 0.58)
			BiomeContentPack.EcologyFamily.MIRROR_WETLAND:
				height = lerpf(height, floorf(height * 0.55) / 0.55, 0.7)
				height -= maxf(sin(x * 0.035) * cos(z * 0.041), 0.0) * 3.8 * pack.basin_bias
			BiomeContentPack.EcologyFamily.ROOT_CAVERN:
				var sink := maxf(_detail_noise.get_noise_2d(x * 0.9 + 260.0, z * 0.9), 0.0)
				height -= pow(sink, 3.0) * 10.0
				height += sin(x * 0.11) * cos(z * 0.09) * 1.4
			BiomeContentPack.EcologyFamily.HEART_PLATEAU:
				var radius := point.length()
				height += sin(radius * 0.09 + atan2(z, x) * 3.0) * 3.2
	var wandering_center := sin(z * 0.018 + float(_run_seed % 97)) * 18.0
	height -= (1.0 - smoothstep(4.0, 15.0, absf(x - wandering_center))) * 3.4
	height = _blend_disc(height, point, Vector2(0, 15), 11.0, 0.0)
	height = _blend_corridor(height, point, Vector2(0, 17), Vector2(0, 49), 4.4, 0.0, 0.35)
	height = _blend_disc(height, point, Vector2(25, 15), 13.0, 0.1)
	var camp_center := Vector2(31.5, 20.5)
	height = lerpf(height, 1.65, 1.0 - smoothstep(4.8, 10.5, point.distance_to(camp_center)))
	var ramp_start := Vector2(20.5, 17.0)
	var ramp_end := Vector2(29.5, 20.0)
	var ramp_distance := _distance_to_segment(point, ramp_start, ramp_end)
	height = lerpf(height, lerpf(0.1, 1.55, _segment_progress(point, ramp_start, ramp_end)), 1.0 - smoothstep(2.0, 4.5, ramp_distance))
	return height


func _terrain_color(point: Vector2, height: float, slope: float) -> Color:
	var pack := _get_content_pack()
	var ground_low := pack.ground_low if pack != null else Color(0.105, 0.205, 0.085)
	var ground_high := pack.ground_high if pack != null else Color(0.31, 0.29, 0.13)
	var color := ground_low.lerp(ground_high, clampf((height + 3.0) / 15.0, 0.0, 1.0))
	var trail := 1.0 - smoothstep(1.15, 3.1, _distance_to_segment(point, Vector2(0, 17), Vector2(0, 49)))
	color = color.lerp(ground_high.darkened(0.18), trail * 0.55)
	var grove := 1.0 - smoothstep(10.0, 25.0, point.distance_to(Vector2(27, 17)))
	color = color.lerp(ground_low.lightened(0.12), grove * 0.35)
	return color.lerp(ground_high.lightened(0.16), smoothstep(0.12, 0.38, slope))


func _build_chunk_decor(body: StaticBody3D, coordinate: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(coordinate)
	var pack := _get_content_pack()
	var vegetation_density := pack.vegetation_density if pack != null else 1.0
	var geology_density := pack.geology_density if pack != null else 1.0
	_add_tree_multimeshes(body, coordinate, rng, maxi(2, roundi(16.0 * vegetation_density)))
	_add_rock_multimesh(body, coordinate, rng, maxi(2, roundi(10.0 * geology_density)))
	var landmark_period := pack.landmark_period if pack != null else 7
	if abs(int(_chunk_seed(coordinate))) % landmark_period == 0:
		_add_point_of_interest(body, coordinate, rng)
	if pack != null and pack.water_frequency > 0.0 and rng.randf() < pack.water_frequency:
		_add_water_feature(body, coordinate, rng, pack)
	if pack != null and pack.cave_frequency > 0.0 and rng.randf() < pack.cave_frequency:
		_add_cave_feature(body, coordinate, rng, pack)
	if _is_altered_phase() and abs(int(_chunk_seed(coordinate))) % 4 == 0:
		_add_mycelial_beacon(body, coordinate, rng)


func _add_tree_multimeshes(body: Node3D, coordinate: Vector2i, rng: RandomNumberGenerator, count: int) -> void:
	var pack := _get_content_pack()
	var family := pack.vegetation_family if pack != null else BiomeContentPack.VegetationFamily.CEDAR_FIR
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.34
	trunk.height = 5.2
	trunk.radial_segments = 7
	var trunk_color := Color(0.24, 0.095, 0.035)
	var crown: PrimitiveMesh
	var crown_layers := 2
	var size_low := 0.75
	var size_high := 1.65
	match family:
		BiomeContentPack.VegetationFamily.CEDAR_FIR:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 1.45
			cone.height = 2.4
			cone.radial_segments = 8
			crown = cone
			crown_layers = 3
		BiomeContentPack.VegetationFamily.GIANT_FUNGI:
			var sphere := SphereMesh.new()
			sphere.radius = 1.8
			sphere.height = 0.72
			sphere.radial_segments = 10
			sphere.rings = 4
			crown = sphere
			trunk_color = Color(0.3, 0.18, 0.32)
			trunk.top_radius = 0.28
			trunk.bottom_radius = 0.42
			crown_layers = 1
		BiomeContentPack.VegetationFamily.ANTLER_LARCH:
			var antler := PrismMesh.new()
			antler.size = Vector3(0.42, 3.5, 0.5)
			crown = antler
			trunk_color = Color(0.16, 0.018, 0.012)
			crown_layers = 4
		BiomeContentPack.VegetationFamily.ICE_LICHEN:
			var crystal := PrismMesh.new()
			crystal.size = Vector3(1.4, 3.8, 1.1)
			crown = crystal
			trunk_color = Color(0.08, 0.28, 0.4)
			crown_layers = 2
			trunk.height = 3.6
		BiomeContentPack.VegetationFamily.BURNT_SNAGS:
			var snag := CylinderMesh.new()
			snag.top_radius = 0.0
			snag.bottom_radius = 0.24
			snag.height = 2.2
			snag.radial_segments = 5
			crown = snag
			trunk_color = Color(0.035, 0.028, 0.025)
			crown_layers = 1
			size_low = 0.62
		BiomeContentPack.VegetationFamily.REED_ISLANDS:
			var seed_head := SphereMesh.new()
			seed_head.radius = 0.18
			seed_head.height = 0.72
			seed_head.radial_segments = 6
			seed_head.rings = 3
			crown = seed_head
			trunk.top_radius = 0.025
			trunk.bottom_radius = 0.05
			trunk.height = 2.4
			trunk_color = Color(0.11, 0.31, 0.22)
			crown_layers = 1
			size_low = 0.45
			size_high = 1.05
		BiomeContentPack.VegetationFamily.ROOT_COLUMNS:
			var ring := TorusMesh.new()
			ring.inner_radius = 0.46
			ring.outer_radius = 1.05
			ring.rings = 10
			ring.ring_segments = 7
			crown = ring
			trunk.top_radius = 0.42
			trunk.bottom_radius = 0.72
			trunk_color = Color(0.22, 0.07, 0.018)
			crown_layers = 2
		_:
			var heart_ring := TorusMesh.new()
			heart_ring.inner_radius = 0.62
			heart_ring.outer_radius = 1.38
			heart_ring.rings = 9
			heart_ring.ring_segments = 6
			crown = heart_ring
			trunk_color = Color(0.08, 0.12, 0.28)
			crown_layers = 3
	trunk.material = _standard_material(trunk_color)
	var crown_low := _phase_definition.canopy_low if _phase_definition != null else Color(0.055, 0.24, 0.075)
	crown.material = _standard_material(crown_low, family != BiomeContentPack.VegetationFamily.CEDAR_FIR)
	var trunks := _new_multimesh(trunk, count)
	var crowns := _new_multimesh(crown, count * crown_layers)
	var placed := 0
	for _attempt in count * 5:
		if placed >= count:
			break
		var point := _random_chunk_point(coordinate, rng)
		if _is_reserved(point):
			continue
		var size := rng.randf_range(size_low, size_high)
		var ground := _height_at(point.x, point.y)
		var yaw := rng.randf_range(0.0, TAU)
		trunks.set_instance_transform(placed, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(size, size, size)), Vector3(point.x, ground + trunk.height * 0.5 * size, point.y)))
		trunks.set_instance_color(placed, Color(0.18, 0.065, 0.025).lerp(Color(0.36, 0.16, 0.05), rng.randf()))
		for layer in crown_layers:
			var crown_scale := size * (1.15 - float(layer) * 0.2)
			var offset := Vector3(0, size * (4.0 + float(layer) * 1.2), 0)
			if family != BiomeContentPack.VegetationFamily.CEDAR_FIR:
				offset += Vector3(cos(yaw + layer * PI), 0, sin(yaw + layer * PI)) * size * 0.65
			if family == BiomeContentPack.VegetationFamily.ANTLER_LARCH:
				offset += Vector3(cos(yaw + layer * 1.57), float(layer) * 0.3, sin(yaw + layer * 1.57)) * size * 1.15
			if family == BiomeContentPack.VegetationFamily.CONCORDANT_GROVE:
				offset.y += sin(float(layer) * 2.1) * size
			var crown_rotation := Vector3(0.0, yaw + layer * 0.3, 0.0)
			if family == BiomeContentPack.VegetationFamily.ROOT_COLUMNS:
				crown_rotation.x = PI * 0.5
			elif family == BiomeContentPack.VegetationFamily.CONCORDANT_GROVE:
				crown_rotation.x = PI * 0.5
				crown_rotation.z = float(layer) * 0.52
			crowns.set_instance_transform(placed * crown_layers + layer, Transform3D(Basis.from_euler(crown_rotation).scaled(Vector3(crown_scale, size, crown_scale)), Vector3(point.x, ground, point.y) + offset))
			var ordinary := Color(0.055, 0.24, 0.075).lerp(Color(0.4, 0.55, 0.12), rng.randf_range(0.0, 0.65))
			var altered_low := _phase_definition.canopy_low if _phase_definition != null else Color(0.15, 0.05, 0.32)
			var altered_high := _phase_definition.canopy_high if _phase_definition != null else Color(0.95, 0.12, 0.62)
			var altered := altered_low.lerp(altered_high, rng.randf_range(0.15, 0.8))
			crowns.set_instance_color(placed * crown_layers + layer, altered if _is_altered_phase() else ordinary)
		placed += 1
	trunks.instance_count = placed
	crowns.instance_count = placed * crown_layers
	_add_multimesh_instance(body, "VegetationTrunks_%d" % family, trunks)
	_add_multimesh_instance(body, "VegetationCrowns_%d" % family, crowns)


func _add_rock_multimesh(body: Node3D, coordinate: Vector2i, rng: RandomNumberGenerator, count: int) -> void:
	var pack := _get_content_pack()
	var family := pack.geology_family if pack != null else BiomeContentPack.GeologyFamily.ROUNDED_GRANITE
	var mesh: PrimitiveMesh
	match family:
		BiomeContentPack.GeologyFamily.ROUNDED_GRANITE, BiomeContentPack.GeologyFamily.ROOT_NODULES:
			var rounded := SphereMesh.new()
			rounded.radius = 0.9
			rounded.height = 1.35
			rounded.radial_segments = 7
			rounded.rings = 3
			mesh = rounded
		BiomeContentPack.GeologyFamily.KARST_RIBS, BiomeContentPack.GeologyFamily.ICE_CRYSTALS, BiomeContentPack.GeologyFamily.FLOATING_STRATA:
			var shard := PrismMesh.new()
			shard.size = Vector3(1.2, 2.8, 1.0)
			mesh = shard
		BiomeContentPack.GeologyFamily.RED_SCREE:
			var scree := PrismMesh.new()
			scree.size = Vector3(1.8, 1.2, 1.4)
			mesh = scree
		BiomeContentPack.GeologyFamily.ASH_COLUMNS:
			var column := CylinderMesh.new()
			column.top_radius = 0.28
			column.bottom_radius = 0.72
			column.height = 2.8
			column.radial_segments = 5
			mesh = column
		_:
			var shelf := CylinderMesh.new()
			shelf.top_radius = 1.15
			shelf.bottom_radius = 1.4
			shelf.height = 0.38
			shelf.radial_segments = 7
			mesh = shelf
	mesh.material = _standard_material(pack.ground_high if pack != null else Color(0.26, 0.28, 0.24), family == BiomeContentPack.GeologyFamily.ICE_CRYSTALS or family == BiomeContentPack.GeologyFamily.FLOATING_STRATA)
	var multimesh := _new_multimesh(mesh, count)
	var placed := 0
	for _attempt in count * 5:
		if placed >= count:
			break
		var point := _random_chunk_point(coordinate, rng)
		if _is_reserved(point):
			continue
		var size := rng.randf_range(0.4, 1.9)
		var ground := _height_at(point.x, point.y)
		var vertical_scale := size * rng.randf_range(0.45, 0.9)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.0, TAU), rng.randf_range(-0.2, 0.2))).scaled(Vector3(size * rng.randf_range(0.8, 1.5), vertical_scale, size))
		var mesh_height := 1.35
		if mesh is PrismMesh:
			mesh_height = (mesh as PrismMesh).size.y
		elif mesh is CylinderMesh:
			mesh_height = (mesh as CylinderMesh).height
		multimesh.set_instance_transform(placed, Transform3D(basis, Vector3(point.x, ground + mesh_height * vertical_scale * 0.42, point.y)))
		var ordinary := Color(0.19, 0.24, 0.2).lerp(Color(0.48, 0.42, 0.28), rng.randf())
		var altered_low := _phase_definition.stone_low if _phase_definition != null else Color(0.08, 0.32, 0.42)
		var altered_high := _phase_definition.stone_high if _phase_definition != null else Color(0.7, 0.16, 0.65)
		var altered := altered_low.lerp(altered_high, rng.randf())
		multimesh.set_instance_color(placed, altered if _is_altered_phase() else ordinary)
		placed += 1
	multimesh.instance_count = placed
	_add_multimesh_instance(body, "Geology_%d" % family, multimesh)


func _add_point_of_interest(body: Node3D, coordinate: Vector2i, rng: RandomNumberGenerator) -> void:
	var center := Vector2((float(coordinate.x) + 0.5) * chunk_size, (float(coordinate.y) + 0.5) * chunk_size)
	if _is_reserved(center):
		return
	var root := Node3D.new()
	root.name = "GeneratedPOI"
	body.add_child(root)
	var pack := _get_content_pack()
	var poi_family := pack.poi_family if pack != null else &"field_station"
	var count := 5 + rng.randi_range(0, 4)
	for index in count:
		var shard := MeshInstance3D.new()
		var mesh: PrimitiveMesh
		match poi_family:
			&"memory_ring", &"root_mouth", &"brothers_heart":
				var ring := TorusMesh.new()
				ring.inner_radius = rng.randf_range(0.7, 1.2)
				ring.outer_radius = ring.inner_radius + rng.randf_range(0.18, 0.34)
				ring.rings = 10
				ring.ring_segments = 7
				mesh = ring
			&"reflection_pool":
				var pool := CylinderMesh.new()
				pool.top_radius = rng.randf_range(1.2, 2.3)
				pool.bottom_radius = pool.top_radius * 1.08
				pool.height = 0.08
				pool.radial_segments = 12
				mesh = pool
			&"vanishing_camp":
				var pole := CylinderMesh.new()
				pole.top_radius = 0.06
				pole.bottom_radius = 0.09
				pole.height = rng.randf_range(2.4, 4.8)
				pole.radial_segments = 5
				mesh = pole
			_:
				var prism := PrismMesh.new()
				prism.size = Vector3(rng.randf_range(0.45, 1.4), rng.randf_range(2.8, 7.0), rng.randf_range(0.45, 1.5))
				mesh = prism
		var accent := pack.accent_color if pack != null else Color(0.55, 0.6, 0.4)
		mesh.material = _standard_material(accent.darkened(rng.randf_range(0.0, 0.38)), _is_altered_phase())
		shard.mesh = mesh
		var angle := TAU * float(index) / float(count) + rng.randf_range(-0.25, 0.25)
		var radius := rng.randf_range(2.0, 5.5)
		var point := center + Vector2(cos(angle), sin(angle)) * radius
		var height_offset := 0.15
		if mesh is PrismMesh:
			height_offset = (mesh as PrismMesh).size.y * 0.45
		elif mesh is CylinderMesh:
			height_offset = (mesh as CylinderMesh).height * 0.5
		else:
			height_offset = 2.0 + float(index) * 0.18
		shard.position = Vector3(point.x, _height_at(point.x, point.y) + height_offset, point.y)
		shard.rotation.y = -angle
		if mesh is TorusMesh:
			shard.rotation.x = PI * 0.5 if poi_family == &"reflection_pool" else 0.0
		root.add_child(shard)
	root.set_meta(&"poi_kind", poi_family)
	if pack != null and not pack.mystery_ids.is_empty():
		root.set_meta(&"mystery_id", pack.mystery_ids[abs(int(_chunk_seed(coordinate))) % pack.mystery_ids.size()])


func _add_water_feature(body: Node3D, coordinate: Vector2i, rng: RandomNumberGenerator, pack: BiomeContentPack) -> void:
	var center := _random_chunk_point(coordinate, rng)
	if _is_reserved(center):
		return
	var pool := MeshInstance3D.new()
	pool.name = "BiomeWater"
	var mesh := CylinderMesh.new()
	mesh.top_radius = rng.randf_range(2.2, 4.8)
	mesh.bottom_radius = mesh.top_radius * 1.08
	mesh.height = 0.055
	mesh.radial_segments = 18
	var material := _standard_material(pack.accent_color.darkened(0.28), true)
	material.metallic = 0.72
	material.roughness = 0.18
	mesh.material = material
	pool.mesh = mesh
	pool.position = Vector3(center.x, _height_at(center.x, center.y) + 0.05, center.y)
	body.add_child(pool)


func _add_cave_feature(body: Node3D, coordinate: Vector2i, rng: RandomNumberGenerator, pack: BiomeContentPack) -> void:
	var center := _random_chunk_point(coordinate, rng)
	if _is_reserved(center):
		return
	var cave := Node3D.new()
	cave.name = "CaveMouth"
	var ground := _height_at(center.x, center.y)
	for index in 5:
		var rib := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 1.15 + float(index) * 0.12
		mesh.outer_radius = mesh.inner_radius + 0.32
		mesh.rings = 10
		mesh.ring_segments = 7
		mesh.material = _standard_material(pack.ground_low.darkened(0.42))
		rib.mesh = mesh
		rib.position = Vector3(center.x, ground + 1.35, center.y + float(index) * 0.42)
		rib.rotation.x = PI * 0.5
		cave.add_child(rib)
	cave.set_meta(&"poi_kind", &"cave_%s" % pack.id)
	body.add_child(cave)


func _add_mycelial_beacon(body: Node3D, coordinate: Vector2i, rng: RandomNumberGenerator) -> void:
	var center := Vector2((float(coordinate.x) + rng.randf_range(0.25, 0.75)) * chunk_size, (float(coordinate.y) + rng.randf_range(0.25, 0.75)) * chunk_size)
	if _is_reserved(center):
		return
	var beacon := MeshInstance3D.new()
	beacon.name = "MycelialBeacon"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.1
	mesh.outer_radius = 1.45
	mesh.rings = 12
	mesh.ring_segments = 8
	mesh.material = _standard_material(_phase_definition.beacon_color if _phase_definition != null else Color(0.9, 0.08, 0.62), true)
	beacon.mesh = mesh
	beacon.position = Vector3(center.x, _height_at(center.x, center.y) + 2.5, center.y)
	beacon.rotation.x = PI * 0.5
	body.add_child(beacon)


func _random_chunk_point(coordinate: Vector2i, rng: RandomNumberGenerator) -> Vector2:
	return Vector2((float(coordinate.x) + rng.randf_range(0.04, 0.96)) * chunk_size, (float(coordinate.y) + rng.randf_range(0.04, 0.96)) * chunk_size)


func _is_reserved(point: Vector2) -> bool:
	if is_instance_valid(_target):
		var target_point := Vector2(_target.global_position.x, _target.global_position.z)
		if point.distance_to(target_point) < 14.0:
			return true
	if point.y < MIN_EXPEDITION_Z + 2.0:
		return true
	if point.distance_to(Vector2(0, 15)) < 9.0:
		return true
	if _distance_to_segment(point, Vector2(0, 17), Vector2(0, 49)) < 3.4:
		return true
	if point.distance_to(Vector2(25, 15)) < 11.0:
		return true
	if point.distance_to(Vector2(60, 15)) < 10.0:
		return true
	return false


func _biome_for_chunk(coordinate: Vector2i) -> int:
	if _is_altered_phase():
		return _phase_definition.geometry_family if _phase_definition != null else 2
	return 0 if _noise.get_noise_2d(float(coordinate.x) * 19.0, float(coordinate.y) * 19.0) < 0.16 else 1


func _is_altered_phase() -> bool:
	return _world_phase != PHASE_ORDINARY


func _get_content_pack() -> BiomeContentPack:
	return _phase_definition.content_pack if _phase_definition != null else null


func _chunk_seed(coordinate: Vector2i) -> int:
	return int(base_seed) * 73856093 ^ int(_run_seed) * 19349663 ^ coordinate.x * 83492791 ^ coordinate.y * 2971215073


func _rebuild_loaded_chunks() -> void:
	var coordinates: Array[Vector2i] = []
	coordinates.assign(_chunks.keys())
	for coordinate: Vector2i in coordinates:
		_chunks[coordinate].queue_free()
	_chunks.clear()
	_pending = coordinates


func _rebuild_world_geometry() -> void:
	var focus := _target.global_position if is_instance_valid(_target) else Vector3(0, 0, 15)
	_rebuild_loaded_chunks()
	_refresh_chunks(focus, true)


func _rebuild_loaded_decor() -> void:
	for coordinate: Vector2i in _chunks:
		var body := _chunks[coordinate]
		for child: Node in body.get_children():
			if child.name != "Terrain" and child.name != "Collision":
				child.queue_free()
		_build_chunk_decor(body, coordinate)


func _new_multimesh(mesh: Mesh, count: int) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	return multimesh


func _add_multimesh_instance(parent: Node3D, node_name: String, multimesh: MultiMesh) -> void:
	if multimesh.instance_count == 0:
		return
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.visibility_range_end = chunk_size * float(active_radius + 1)
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(instance)


func _standard_material(color: Color, emission: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.2
	return material


func _build_terrain_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform float metamorphosis : hint_range(0.0, 1.0) = 0.0;
uniform vec3 phase_low : source_color = vec3(0.025, 0.16, 0.32);
uniform vec3 phase_high : source_color = vec3(0.82, 0.025, 0.7);
varying float pulse;
void vertex() {
	float wave_a = sin(VERTEX.x * 0.075 + TIME * 0.65);
	float wave_b = cos(VERTEX.z * 0.061 - TIME * 0.48);
	pulse = wave_a * wave_b;
	VERTEX.y += pulse * 0.32 * metamorphosis;
}
void fragment() {
	vec3 mundane = COLOR.rgb;
	float bands = 0.5 + 0.5 * sin((VERTEX.x + VERTEX.z) * 0.09 + pulse * 2.0);
	vec3 altered = mix(phase_low, phase_high, bands);
	ALBEDO = mix(mundane, altered, metamorphosis * 0.96);
	ROUGHNESS = mix(0.96, 0.62, metamorphosis);
	EMISSION = altered * metamorphosis * (0.3 + max(pulse, 0.0) * 0.45);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"metamorphosis", _phase_amount)
	return material


func _blend_disc(current: float, point: Vector2, center: Vector2, radius: float, target_height: float) -> float:
	var blend := 1.0 - smoothstep(radius * 0.58, radius, point.distance_to(center))
	return lerpf(current, target_height, blend)


func _blend_corridor(current: float, point: Vector2, start: Vector2, end: Vector2, width: float, start_height: float, end_height: float) -> float:
	var blend := 1.0 - smoothstep(width * 0.55, width, _distance_to_segment(point, start, end))
	return lerpf(current, lerpf(start_height, end_height, _segment_progress(point, start, end)), blend)


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var t := clampf((point - start).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
	return point.distance_to(start + segment * t)


func _segment_progress(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	return clampf((point - start).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
