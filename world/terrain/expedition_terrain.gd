class_name ExpeditionTerrain
extends StaticBody3D

signal mystery_discovered(definition: WorldMysteryDefinition)
signal mystery_event_started(definition: WorldMysteryDefinition, instruction: String)
signal mystery_event_failed(definition: WorldMysteryDefinition, failure_text: String)
signal mystery_event_progressed(definition: WorldMysteryDefinition, progress: float, pressure: float)
signal biome_ingredient_harvested(item: ItemInstance)
signal biome_ingredient_observed(definition_id: StringName)

const PHASE_ORDINARY: StringName = &"ordinary"
const PHASE_MYCELIAL: StringName = &"mycelial"
const MIN_EXPEDITION_Z: float = 5.8
const BIOME_MESH_LIBRARY = preload("res://world/terrain/biome_mesh_library.gd")
const BIOME_AMBIENCE = preload("res://presentation/audio/biome_procedural_ambience.gd")
const ECOLOGY_MOTION_SHADER = preload("res://presentation/shaders/ecology_motion.gdshader")

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
var _horizon_root: Node3D
var _atmosphere: GPUParticles3D
var _generated_mesh_cache: Dictionary[StringName, Mesh] = {}
var _mesh_library: RefCounted = BIOME_MESH_LIBRARY.new()
var _biome_ambience: AudioStreamPlayer
var _decor_exclusion_centers: Array[Vector2] = []
var _collected_biome_ingredient_spawns: Dictionary[StringName, bool] = {}
var _discovered_mystery_ids: Dictionary[StringName, bool] = {}


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
	_rebuild_presentation_layers()


func ensure_area_at(world_position: Vector3) -> void:
	_refresh_chunks(world_position, true)


func set_run_seed(value: int) -> void:
	if _run_seed == value:
		return
	_run_seed = value
	_configure_noise()
	_rebuild_loaded_chunks()
	_rebuild_presentation_layers()


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
	_rebuild_presentation_layers()


func get_world_phase() -> StringName:
	return _world_phase


func get_loaded_chunk_count() -> int:
	return _chunks.size()


func get_loaded_chunk_nodes() -> Array[StaticBody3D]:
	var result: Array[StaticBody3D] = []
	result.assign(_chunks.values())
	return result


func get_generated_mesh_cache_size() -> int:
	return _generated_mesh_cache.size()


func get_ambience_ecology_family() -> int:
	return int(_biome_ambience.get("ecology_family")) if is_instance_valid(_biome_ambience) else -1


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


func get_collected_biome_ingredient_spawns() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_collected_biome_ingredient_spawns.keys())
	return result


func apply_collected_biome_ingredient_spawns(values: Array) -> void:
	_collected_biome_ingredient_spawns.clear()
	for raw_id: Variant in values:
		_collected_biome_ingredient_spawns[StringName(raw_id)] = true
	for node: Node in find_children("*", "GeneratedBiomeIngredient", true, false):
		var sample := node as GeneratedBiomeIngredient
		if _collected_biome_ingredient_spawns.has(sample.spawn_id):
			sample.queue_free()


func apply_discovered_mysteries(values: Array) -> void:
	_discovered_mystery_ids.clear()
	for raw_id: Variant in values:
		_discovered_mystery_ids[StringName(raw_id)] = true
	for node: Node in find_children("*", "WorldMysteryPOI", true, false):
		var poi := node as WorldMysteryPOI
		if poi.definition != null:
			poi.set_completed(_discovered_mystery_ids.has(poi.definition.id))


func simulate_nearest_mystery_event() -> bool:
	var nearest: WorldMysteryPOI
	var nearest_distance := INF
	for node: Node in find_children("*", "WorldMysteryPOI", true, false):
		var poi := node as WorldMysteryPOI
		if poi.is_completed() or poi.definition == null:
			continue
		var collision := poi.find_child("MysteryCollision", true, false) as CollisionShape3D
		var center := collision.global_position if collision != null else poi.global_position
		var distance := center.distance_to(_target.global_position) if is_instance_valid(_target) else 0.0
		if distance < nearest_distance:
			nearest = poi
			nearest_distance = distance
	return nearest != null and nearest.simulate_resolution()


func _process(_delta: float) -> void:
	if is_instance_valid(_target):
		var expedition_visible := _target.global_position.z >= MIN_EXPEDITION_Z
		if is_instance_valid(_horizon_root):
			_horizon_root.visible = expedition_visible
			_horizon_root.global_position = Vector3(_target.global_position.x, _target.global_position.y - 9.0, _target.global_position.z)
		if is_instance_valid(_atmosphere):
			_atmosphere.visible = expedition_visible
			_atmosphere.global_position = _target.global_position + Vector3(0.0, 4.0, 0.0)
		if is_instance_valid(_biome_ambience):
			_biome_ambience.volume_db = -13.0 if expedition_visible else -80.0
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
	body.set_meta(&"chunk_coordinate", coordinate)
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
	var route_distance := _distance_to_expedition_route(point)
	height -= (1.0 - smoothstep(4.0, 15.0, route_distance)) * 3.4
	var terrain_coordinate := Vector2i(floori(x / chunk_size), floori(z / chunk_size))
	if _should_place_landmark(terrain_coordinate, pack):
		var landmark_center := _landmark_center(terrain_coordinate, pack)
		if landmark_center.y >= MIN_EXPEDITION_Z + 2.0:
			var landmark_height := _noise.get_noise_2d(landmark_center.x, landmark_center.y) * 5.2 * elevation_scale
			height = _blend_disc(height, point, landmark_center, 9.5, landmark_height)
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
	var authored_trail := 1.0 - smoothstep(1.15, 3.1, _distance_to_segment(point, Vector2(0, 17), Vector2(0, 49)))
	var expedition_route := 1.0 - smoothstep(1.3, 4.6, _distance_to_expedition_route(point))
	color = color.lerp(ground_high.darkened(0.18), maxf(authored_trail * 0.55, expedition_route * 0.42))
	var grove := 1.0 - smoothstep(10.0, 25.0, point.distance_to(Vector2(27, 17)))
	color = color.lerp(ground_low.lightened(0.12), grove * 0.35)
	return color.lerp(ground_high.lightened(0.16), smoothstep(0.12, 0.38, slope))


func _build_chunk_decor(body: StaticBody3D, coordinate: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(coordinate)
	var pack := _get_content_pack()
	var vegetation_density := pack.vegetation_density if pack != null else 1.0
	var geology_density := pack.geology_density if pack != null else 1.0
	var has_landmark := _should_place_landmark(coordinate, pack)
	var landmark_center := _landmark_center(coordinate, pack)
	_decor_exclusion_centers.clear()
	if has_landmark and not _is_reserved(landmark_center):
		_decor_exclusion_centers.append(landmark_center)
	_add_tree_multimeshes(body, coordinate, rng, maxi(2, roundi(16.0 * vegetation_density)))
	_add_rock_multimesh(body, coordinate, rng, maxi(2, roundi(10.0 * geology_density)))
	_add_groundcover_multimesh(body, coordinate, rng, maxi(6, roundi(34.0 * vegetation_density)))
	if pack != null and _should_place_ecology_composition(coordinate, pack):
		_add_ecology_composition(body, coordinate, rng, pack)
	_decor_exclusion_centers.clear()
	if has_landmark:
		_add_point_of_interest(body, coordinate, rng)
	if pack != null and pack.water_frequency > 0.0 and rng.randf() < pack.water_frequency:
		_add_water_feature(body, coordinate, rng, pack)
	if pack != null and pack.cave_frequency > 0.0 and rng.randf() < pack.cave_frequency:
		_add_cave_feature(body, coordinate, rng, pack)
	if _is_altered_phase() and abs(int(_chunk_seed(coordinate))) % 4 == 0:
		_add_mycelial_beacon(body, coordinate, rng)


func _add_ecology_composition(body: Node3D, coordinate: Vector2i, rng: RandomNumberGenerator, pack: BiomeContentPack) -> void:
	var center := _composition_center_for_row(coordinate.y, pack)
	var root := Node3D.new()
	root.name = "EcologyComposition_%s" % pack.composition_family
	root.set_meta(&"composition_family", pack.composition_family)
	root.set_meta(&"art_directed", true)
	body.add_child(root)
	var scale := pack.composition_scale
	match pack.composition_family:
		&"cedar_windfall":
			_add_cedar_windfall(root, center, rng, pack, scale)
		&"fungal_nursery":
			_add_fungal_nursery(root, center, rng, pack, scale)
		&"antler_migration":
			_add_antler_migration(root, center, rng, pack, scale)
		&"ice_organ":
			_add_ice_organ(root, center, rng, pack, scale)
		&"burn_scar":
			_add_burn_scar(root, center, rng, pack, scale)
		&"reed_mirror_island":
			_add_reed_mirror_island(root, center, rng, pack, scale)
		&"root_nave":
			_add_root_nave(root, center, rng, pack, scale)
		_:
			_add_floating_concordance(root, center, rng, pack, scale)


func _add_cedar_windfall(root: Node3D, center: Vector2, rng: RandomNumberGenerator, pack: BiomeContentPack, scale: float) -> void:
	var wood := _standard_material(Color("412719"))
	var granite := _standard_material(pack.ground_high.darkened(0.22))
	for index: int in 3:
		var offset := Vector2(float(index - 1) * 1.5, rng.randf_range(-0.65, 0.65)) * scale
		_add_composition_mesh(root, BIOME_MESH_LIBRARY.create_taiga_trunk(), center + offset, 0.32 * scale, Vector3(scale * rng.randf_range(0.72, 1.08), scale, scale), Vector3(0.0, rng.randf_range(-0.28, 0.28), PI * 0.5), wood)
	for index: int in 5:
		var angle := TAU * float(index) / 5.0 + 0.35
		var offset := Vector2(cos(angle), sin(angle)) * rng.randf_range(2.4, 4.6) * scale
		_add_composition_mesh(root, BIOME_MESH_LIBRARY.create_granite_boulder(), center + offset, 0.0, Vector3.ONE * rng.randf_range(0.7, 1.45) * scale, Vector3(0.0, angle, rng.randf_range(-0.15, 0.15)), granite)


func _add_fungal_nursery(root: Node3D, center: Vector2, rng: RandomNumberGenerator, pack: BiomeContentPack, scale: float) -> void:
	var stem_material := _standard_material(Color(0.26, 0.12, 0.3))
	var cap_material := _standard_material(pack.accent_color.darkened(0.12), true)
	for index: int in 7:
		var angle := TAU * float(index) / 7.0 + rng.randf_range(-0.24, 0.24)
		var radius := (1.0 + float(index % 3) * 0.82) * scale
		var point := center + Vector2(cos(angle), sin(angle)) * radius
		var mushroom_scale := scale * rng.randf_range(0.38, 0.9)
		_add_composition_mesh(root, BIOME_MESH_LIBRARY.create_fungus_stem(), point, 0.0, Vector3.ONE * mushroom_scale, Vector3(0.0, angle, 0.0), stem_material)
		_add_composition_mesh(root, BIOME_MESH_LIBRARY.create_fungus_cap(), point, 4.15 * mushroom_scale, Vector3(mushroom_scale * 1.2, mushroom_scale, mushroom_scale * 1.2), Vector3(0.0, angle, 0.0), cap_material)


func _add_antler_migration(root: Node3D, center: Vector2, rng: RandomNumberGenerator, pack: BiomeContentPack, scale: float) -> void:
	var bone := _standard_material(pack.accent_color.darkened(0.38))
	var echo := _standard_material(Color(0.24, 0.012, 0.008), true)
	for index: int in 6:
		var offset := Vector2(float(index - 2) * 1.45, sin(float(index) * 1.7) * 1.2) * scale
		var point := center + offset
		var size := scale * rng.randf_range(0.72, 1.18)
		_add_composition_mesh(root, BIOME_MESH_LIBRARY.create_antler_crown(), point, 0.1, Vector3.ONE * size, Vector3(0.0, rng.randf_range(-0.45, 0.45), (-0.08 if index % 2 == 0 else 0.12)), bone)
	if _is_altered_phase():
		_add_composition_mesh(root, BIOME_MESH_LIBRARY.create_false_beast_echo(), center + Vector2(0.0, -2.8 * scale), 0.5 * scale, Vector3.ONE * 1.6 * scale, Vector3(0.0, PI * 0.5, 0.0), echo)


func _add_ice_organ(root: Node3D, center: Vector2, rng: RandomNumberGenerator, pack: BiomeContentPack, scale: float) -> void:
	var ice := _standard_material(pack.accent_color.lightened(0.08), true)
	for index: int in 7:
		var offset := Vector2(float(index - 3) * 1.05, absf(float(index - 3)) * 0.28) * scale
		var height_scale := scale * (0.65 + (3.5 - absf(float(index) - 3.0)) * 0.18)
		_add_composition_mesh(root, BIOME_MESH_LIBRARY.create_crystal_cluster(), center + offset, 0.0, Vector3(scale * 0.78, height_scale, scale * 0.78), Vector3(0.0, rng.randf_range(-0.3, 0.3), 0.0), ice)


func _add_burn_scar(root: Node3D, center: Vector2, rng: RandomNumberGenerator, pack: BiomeContentPack, scale: float) -> void:
	var char_material := _standard_material(Color(0.025, 0.02, 0.018))
	var ash_material := _standard_material(pack.ground_high.darkened(0.34))
	for index: int in 8:
		var angle := TAU * float(index) / 8.0 + rng.randf_range(-0.16, 0.16)
		var point := center + Vector2(cos(angle), sin(angle)) * rng.randf_range(1.6, 4.2) * scale
		var mesh: Mesh = BIOME_MESH_LIBRARY.create_burnt_crown() if index % 2 == 0 else BIOME_MESH_LIBRARY.create_ash_column()
		var material := char_material if index % 2 == 0 else ash_material
		_add_composition_mesh(root, mesh, point, 0.0, Vector3.ONE * rng.randf_range(0.72, 1.4) * scale, Vector3(0.0, angle, rng.randf_range(-0.13, 0.13)), material)


func _add_reed_mirror_island(root: Node3D, center: Vector2, rng: RandomNumberGenerator, pack: BiomeContentPack, scale: float) -> void:
	var water_mesh := CylinderMesh.new()
	water_mesh.top_radius = 4.4 * scale
	water_mesh.bottom_radius = 4.65 * scale
	water_mesh.height = 0.045
	water_mesh.radial_segments = 18
	var water := _standard_material(pack.accent_color.darkened(0.32), true)
	water.metallic = 0.78
	water.roughness = 0.12
	_add_composition_mesh(root, water_mesh, center, 0.04, Vector3.ONE, Vector3.ZERO, water)
	var reed_material := _standard_material(Color(0.055, 0.31, 0.19))
	for index: int in 13:
		var angle := TAU * float(index) / 13.0 + rng.randf_range(-0.18, 0.18)
		var radius := rng.randf_range(2.5, 4.2) * scale
		var point := center + Vector2(cos(angle), sin(angle)) * radius
		_add_composition_mesh(root, BIOME_MESH_LIBRARY.create_reed_head(), point, 0.0, Vector3.ONE * rng.randf_range(1.5, 2.6) * scale, Vector3(0.0, angle, 0.0), reed_material)


func _add_root_nave(root: Node3D, center: Vector2, rng: RandomNumberGenerator, pack: BiomeContentPack, scale: float) -> void:
	var root_material := _standard_material(pack.ground_high.darkened(0.3))
	for index: int in 5:
		var offset := Vector2(float(index - 2) * 1.55, absf(float(index - 2)) * 0.42) * scale
		var size := scale * (1.15 - absf(float(index - 2)) * 0.08)
		_add_composition_mesh(root, BIOME_MESH_LIBRARY.create_root_loop(), center + offset, 0.15, Vector3.ONE * size, Vector3(0.0, rng.randf_range(-0.18, 0.18), 0.0), root_material)


func _add_floating_concordance(root: Node3D, center: Vector2, rng: RandomNumberGenerator, pack: BiomeContentPack, scale: float) -> void:
	var strata_material := _standard_material(pack.ground_high.darkened(0.2), true)
	var ring_material := _standard_material(pack.accent_color, true)
	for index: int in 6:
		var angle := TAU * float(index) / 6.0
		var point := center + Vector2(cos(angle), sin(angle)) * (2.2 + float(index % 2)) * scale
		_add_composition_mesh(root, BIOME_MESH_LIBRARY.create_floating_strata(), point, (1.2 + float(index % 3) * 1.05) * scale, Vector3.ONE * rng.randf_range(0.75, 1.25) * scale, Vector3(0.0, angle, 0.0), strata_material)
	_add_composition_mesh(root, BIOME_MESH_LIBRARY.create_heart_loop(), center, 3.2 * scale, Vector3.ONE * 1.8 * scale, Vector3(0.0, 0.0, rng.randf_range(-0.16, 0.16)), ring_material)


func _add_composition_mesh(root: Node3D, mesh: Mesh, point: Vector2, height_offset: float, scale: Vector3, rotation: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = Vector3(point.x, _height_at(point.x, point.y) + height_offset, point.y)
	instance.scale = scale
	instance.rotation = rotation
	root.add_child(instance)


func _add_tree_multimeshes(body: Node3D, coordinate: Vector2i, rng: RandomNumberGenerator, count: int) -> void:
	var pack := _get_content_pack()
	var family := pack.vegetation_family if pack != null else BiomeContentPack.VegetationFamily.CEDAR_FIR
	var trunk_shape := CylinderMesh.new()
	trunk_shape.top_radius = 0.12
	trunk_shape.bottom_radius = 0.34
	trunk_shape.height = 5.2
	trunk_shape.radial_segments = 7
	var trunk: Mesh = trunk_shape
	var trunk_height := 5.2
	var trunk_has_base_origin := false
	var trunk_color := Color(0.24, 0.095, 0.035)
	var crown: Mesh
	var crown_layers := 2
	var size_low := 0.75
	var size_high := 1.65
	match family:
		BiomeContentPack.VegetationFamily.CEDAR_FIR:
			trunk = _cached_biome_mesh(&"taiga_trunk", "create_taiga_trunk")
			trunk_height = 5.8
			trunk_has_base_origin = true
			crown = _cached_biome_mesh(&"conifer_crown", "create_conifer_crown")
			crown_layers = 1
		BiomeContentPack.VegetationFamily.GIANT_FUNGI:
			trunk = _cached_biome_mesh(&"fungus_stem", "create_fungus_stem")
			trunk_height = 5.4
			trunk_has_base_origin = true
			crown = _cached_biome_mesh(&"fungus_cap", "create_fungus_cap")
			trunk_color = Color(0.3, 0.18, 0.32)
			crown_layers = 1
		BiomeContentPack.VegetationFamily.ANTLER_LARCH:
			trunk = _cached_biome_mesh(&"taiga_trunk", "create_taiga_trunk")
			trunk_height = 5.8
			trunk_has_base_origin = true
			crown = _cached_biome_mesh(&"antler_crown", "create_antler_crown")
			trunk_color = Color(0.16, 0.018, 0.012)
			crown_layers = 1
		BiomeContentPack.VegetationFamily.ICE_LICHEN:
			crown = _cached_biome_mesh(&"crystal_cluster", "create_crystal_cluster")
			trunk_color = Color(0.08, 0.28, 0.4)
			crown_layers = 1
			trunk_shape.height = 3.6
			trunk_height = 3.6
		BiomeContentPack.VegetationFamily.BURNT_SNAGS:
			trunk = _cached_biome_mesh(&"taiga_trunk", "create_taiga_trunk")
			trunk_height = 5.8
			trunk_has_base_origin = true
			crown = _cached_biome_mesh(&"burnt_crown", "create_burnt_crown")
			trunk_color = Color(0.035, 0.028, 0.025)
			crown_layers = 1
			size_low = 0.62
		BiomeContentPack.VegetationFamily.REED_ISLANDS:
			crown = _cached_biome_mesh(&"reed_head", "create_reed_head")
			trunk_shape.top_radius = 0.025
			trunk_shape.bottom_radius = 0.05
			trunk_shape.height = 2.4
			trunk_height = 2.4
			trunk_color = Color(0.11, 0.31, 0.22)
			crown_layers = 1
			size_low = 0.45
			size_high = 1.05
		BiomeContentPack.VegetationFamily.ROOT_COLUMNS:
			crown = _cached_biome_mesh(&"root_loop", "create_root_loop")
			trunk_shape.top_radius = 0.42
			trunk_shape.bottom_radius = 0.72
			trunk_color = Color(0.22, 0.07, 0.018)
			crown_layers = 2
		_:
			crown = _cached_biome_mesh(&"heart_loop", "create_heart_loop")
			trunk_color = Color(0.08, 0.12, 0.28)
			crown_layers = 3
	_set_mesh_material(trunk, _standard_material(trunk_color))
	var crown_low := _phase_definition.canopy_low if _phase_definition != null else Color(0.055, 0.24, 0.075)
	_set_mesh_material(crown, _ecology_motion_material(crown_low, pack, 0.34, 0.14 if _is_altered_phase() else 0.0))
	var trunks := _new_multimesh(trunk, count)
	var crowns := _new_multimesh(crown, count * crown_layers)
	var placed := 0
	for _attempt in count * 5:
		if placed >= count:
			break
		var point := _random_chunk_point(coordinate, rng)
		if _is_reserved(point):
			continue
		if not _accept_ecology_point(point, 0, pack):
			continue
		var size := rng.randf_range(size_low, size_high)
		var ground := _height_at(point.x, point.y)
		var yaw := rng.randf_range(0.0, TAU)
		var trunk_y := ground if trunk_has_base_origin else ground + trunk_height * 0.5 * size
		trunks.set_instance_transform(placed, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(size, size, size)), Vector3(point.x, trunk_y, point.y)))
		trunks.set_instance_color(placed, Color(0.18, 0.065, 0.025).lerp(Color(0.36, 0.16, 0.05), rng.randf()))
		for layer in crown_layers:
			var crown_scale := size * (1.15 - float(layer) * 0.2)
			var offset := Vector3(0, size * (trunk_height * 0.57 + float(layer) * 1.2), 0)
			if family != BiomeContentPack.VegetationFamily.CEDAR_FIR:
				offset += Vector3(cos(yaw + layer * PI), 0, sin(yaw + layer * PI)) * size * 0.65
			if family == BiomeContentPack.VegetationFamily.ANTLER_LARCH:
				offset += Vector3(cos(yaw + layer * 1.57), float(layer) * 0.3, sin(yaw + layer * 1.57)) * size * 1.15
			if family == BiomeContentPack.VegetationFamily.CONCORDANT_GROVE:
				offset.y += sin(float(layer) * 2.1) * size
			var crown_rotation := Vector3(0.0, yaw + layer * 0.3, 0.0)
			if family == BiomeContentPack.VegetationFamily.CONCORDANT_GROVE:
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
	var mesh: Mesh
	match family:
		BiomeContentPack.GeologyFamily.ROUNDED_GRANITE:
			mesh = _cached_biome_mesh(&"granite_boulder", "create_granite_boulder")
		BiomeContentPack.GeologyFamily.ROOT_NODULES:
			mesh = _cached_biome_mesh(&"root_nodule", "create_root_nodule")
		BiomeContentPack.GeologyFamily.KARST_RIBS:
			mesh = _cached_biome_mesh(&"karst_rib", "create_karst_rib")
		BiomeContentPack.GeologyFamily.ICE_CRYSTALS:
			mesh = _cached_biome_mesh(&"ice_geology", "create_ice_geology")
		BiomeContentPack.GeologyFamily.FLOATING_STRATA:
			mesh = _cached_biome_mesh(&"floating_strata", "create_floating_strata")
		BiomeContentPack.GeologyFamily.RED_SCREE:
			mesh = _cached_biome_mesh(&"red_scree", "create_red_scree")
		BiomeContentPack.GeologyFamily.ASH_COLUMNS:
			mesh = _cached_biome_mesh(&"ash_column", "create_ash_column")
		_:
			mesh = _cached_biome_mesh(&"wetland_shelf", "create_wetland_shelf")
	_set_mesh_material(mesh, _standard_material(pack.ground_high if pack != null else Color(0.26, 0.28, 0.24), family == BiomeContentPack.GeologyFamily.ICE_CRYSTALS or family == BiomeContentPack.GeologyFamily.FLOATING_STRATA))
	var multimesh := _new_multimesh(mesh, count)
	var placed := 0
	for _attempt in count * 5:
		if placed >= count:
			break
		var point := _random_chunk_point(coordinate, rng)
		if _is_reserved(point):
			continue
		if not _accept_ecology_point(point, 1, pack):
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
		else:
			match family:
				BiomeContentPack.GeologyFamily.KARST_RIBS: mesh_height = 3.5
				BiomeContentPack.GeologyFamily.ROUNDED_GRANITE: mesh_height = 1.55
				BiomeContentPack.GeologyFamily.RED_SCREE: mesh_height = 1.2
				BiomeContentPack.GeologyFamily.ICE_CRYSTALS: mesh_height = 3.4
				BiomeContentPack.GeologyFamily.ASH_COLUMNS: mesh_height = 3.1
				BiomeContentPack.GeologyFamily.WETLAND_SHELVES: mesh_height = 0.58
				BiomeContentPack.GeologyFamily.ROOT_NODULES: mesh_height = 1.8
				BiomeContentPack.GeologyFamily.FLOATING_STRATA: mesh_height = 1.44
		multimesh.set_instance_transform(placed, Transform3D(basis, Vector3(point.x, ground + mesh_height * vertical_scale * 0.42, point.y)))
		var ordinary := Color(0.19, 0.24, 0.2).lerp(Color(0.48, 0.42, 0.28), rng.randf())
		var altered_low := _phase_definition.stone_low if _phase_definition != null else Color(0.08, 0.32, 0.42)
		var altered_high := _phase_definition.stone_high if _phase_definition != null else Color(0.7, 0.16, 0.65)
		var altered := altered_low.lerp(altered_high, rng.randf())
		multimesh.set_instance_color(placed, altered if _is_altered_phase() else ordinary)
		placed += 1
	multimesh.instance_count = placed
	_add_multimesh_instance(body, "Geology_%d" % family, multimesh)


func _add_groundcover_multimesh(body: Node3D, coordinate: Vector2i, rng: RandomNumberGenerator, count: int) -> void:
	var pack := _get_content_pack()
	if pack == null:
		return
	var ecology := pack.ecology_family
	var mesh: Mesh = _cached_biome_mesh(StringName("groundcover_%d" % ecology), &"create_ecology_groundcover", [ecology])
	var colors := [
		Color(0.19, 0.36, 0.08), Color(0.96, 0.08, 0.58), Color(0.68, 0.035, 0.012), Color(0.34, 0.82, 0.96),
		Color(0.12, 0.095, 0.075), Color(0.08, 0.48, 0.34), Color(0.62, 0.16, 0.025), Color(0.92, 0.14, 0.72),
	]
	var color: Color = colors[ecology]
	var material := _ecology_motion_material(color, pack, 1.65, 0.12 if ecology != BiomeContentPack.EcologyFamily.ALTAI_TAIGA else 0.0)
	_set_mesh_material(mesh, material)
	var multimesh := _new_multimesh(mesh, count)
	var placed := 0
	for _attempt in count * 5:
		if placed >= count:
			break
		var point := _random_chunk_point(coordinate, rng)
		if _is_reserved(point):
			continue
		if not _accept_ecology_point(point, 2, pack):
			continue
		var ground := _height_at(point.x, point.y)
		var scale := rng.randf_range(0.72, 1.55)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(scale, scale, scale))
		multimesh.set_instance_transform(placed, Transform3D(basis, Vector3(point.x, ground + 0.025, point.y)))
		var tint := color.lerp(pack.accent_color, rng.randf_range(0.0, 0.32))
		multimesh.set_instance_color(placed, tint)
		placed += 1
	multimesh.instance_count = placed
	_add_multimesh_instance(body, "Groundcover_%d" % ecology, multimesh)


func _add_point_of_interest(body: Node3D, coordinate: Vector2i, rng: RandomNumberGenerator) -> void:
	var pack := _get_content_pack()
	var center := _landmark_center(coordinate, pack)
	if center.y < MIN_EXPEDITION_Z + 2.0:
		return
	var root := WorldMysteryPOI.new()
	root.name = "GeneratedPOI"
	body.add_child(root)
	var poi_family := pack.poi_family if pack != null else &"field_station"
	var mystery: WorldMysteryDefinition
	if pack != null and not pack.mysteries.is_empty():
		mystery = pack.mysteries[abs(int(_chunk_seed(coordinate))) % pack.mysteries.size()]
	if poi_family == &"field_station":
		_build_altai_waymark(root, center, rng)
		root.set_meta(&"poi_kind", &"altai_waymark")
		root.set_meta(&"mystery_id", &"mystery.altai.bound_thread")
		_configure_generated_poi_content(root, center, coordinate, pack, mystery)
		return
	var count := 6 if poi_family == &"predator_shrine" else 5 + rng.randi_range(0, 4)
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
			&"predator_shrine":
				var antler := CylinderMesh.new()
				antler.top_radius = 0.035
				antler.bottom_radius = 0.12
				antler.height = rng.randf_range(2.3, 3.4)
				antler.radial_segments = 5
				mesh = antler
			_:
				var prism := PrismMesh.new()
				prism.size = Vector3(rng.randf_range(0.45, 1.4), rng.randf_range(2.8, 7.0), rng.randf_range(0.45, 1.5))
				mesh = prism
		var accent := pack.accent_color if pack != null else Color(0.55, 0.6, 0.4)
		# Structural silhouettes stay matte. Emission is reserved for the event core,
		# otherwise an altered biome turns into a flat wall of neon.
		mesh.material = _standard_material(accent.darkened(rng.randf_range(0.34, 0.62)), false)
		shard.mesh = mesh
		var angle := TAU * float(index) / float(count) + rng.randf_range(-0.25, 0.25)
		var radius := rng.randf_range(4.8, 6.2) if poi_family == &"predator_shrine" else rng.randf_range(2.0, 5.5)
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
			shard.rotation.x = PI * 0.5
		if poi_family == &"predator_shrine":
			shard.rotation.z = (-0.18 if index % 2 == 0 else 0.18) + rng.randf_range(-0.06, 0.06)
		if poi_family == &"frozen_archive":
			shard.rotation.z = rng.randf_range(-0.24, 0.24)
		root.add_child(shard)
	if poi_family == &"vanishing_camp":
		_add_vanishing_camp_remains(root, center, rng, pack)
	elif poi_family == &"predator_shrine":
		_add_predator_shrine_heart(root, center, rng, pack)
	elif poi_family == &"frozen_archive":
		_add_frozen_archive_core(root, center, rng, pack)
	root.set_meta(&"poi_kind", poi_family)
	if pack != null and not pack.mystery_ids.is_empty():
		root.set_meta(&"mystery_id", pack.mystery_ids[abs(int(_chunk_seed(coordinate))) % pack.mystery_ids.size()])
	_configure_generated_poi_content(root, center, coordinate, pack, mystery)


func _add_vanishing_camp_remains(root: Node3D, center: Vector2, rng: RandomNumberGenerator, pack: BiomeContentPack) -> void:
	var ground := _height_at(center.x, center.y)
	var cloth := MeshInstance3D.new()
	cloth.name = "HalfErasedTentSkin"
	var mesh := PrismMesh.new()
	mesh.size = Vector3(4.2, 0.08, 2.7)
	mesh.material = _standard_material(pack.accent_color.darkened(0.48), true)
	cloth.mesh = mesh
	cloth.position = Vector3(center.x, ground + 2.25, center.y)
	cloth.rotation = Vector3(0.0, rng.randf_range(-0.4, 0.4), 0.12)
	root.add_child(cloth)
	for index: int in 6:
		var ember := MeshInstance3D.new()
		var ember_mesh := BoxMesh.new()
		ember_mesh.size = Vector3(0.28, 0.12, 0.22)
		ember_mesh.material = _standard_material(pack.accent_color.darkened(float(index) * 0.06), index < 2)
		ember.mesh = ember_mesh
		var angle := TAU * float(index) / 6.0
		ember.position = Vector3(center.x + cos(angle) * 0.65, ground + 0.08, center.y + sin(angle) * 0.65)
		root.add_child(ember)


func _add_predator_shrine_heart(root: Node3D, center: Vector2, rng: RandomNumberGenerator, pack: BiomeContentPack) -> void:
	var ground := _height_at(center.x, center.y)
	var antler_arch := MeshInstance3D.new()
	antler_arch.name = "PredatorAntlerArch"
	var antler_mesh := BIOME_MESH_LIBRARY.create_antler_crown()
	_set_mesh_material(antler_mesh, _standard_material(pack.ground_high.lightened(0.08)))
	antler_arch.mesh = antler_mesh
	antler_arch.scale = Vector3(1.72, 1.72, 1.72)
	antler_arch.position = Vector3(center.x, ground + 0.1, center.y + 0.65)
	antler_arch.rotation.y = PI
	root.add_child(antler_arch)
	var heart := MeshInstance3D.new()
	heart.name = "WarmBoneWithoutBeast"
	var mesh := SphereMesh.new()
	mesh.radius = 0.58
	mesh.height = 1.25
	mesh.radial_segments = 7
	mesh.rings = 5
	mesh.material = _standard_material(pack.accent_color, true)
	heart.mesh = mesh
	heart.scale = Vector3(0.65, 1.0, 0.5)
	heart.position = Vector3(center.x, ground + 0.7, center.y)
	heart.rotation.y = rng.randf_range(0.0, TAU)
	root.add_child(heart)
	for index: int in 8:
		var altar_stone := MeshInstance3D.new()
		altar_stone.name = "ShrineStone_%02d" % index
		var stone_mesh := BoxMesh.new()
		stone_mesh.size = Vector3(0.52, 0.26, 0.42)
		stone_mesh.material = _standard_material(pack.ground_low.darkened(0.22))
		altar_stone.mesh = stone_mesh
		var angle := TAU * float(index) / 8.0
		altar_stone.position = Vector3(center.x + cos(angle) * 1.4, ground + 0.13, center.y + sin(angle) * 1.4)
		altar_stone.rotation.y = -angle
		root.add_child(altar_stone)


func _add_frozen_archive_core(root: Node3D, center: Vector2, rng: RandomNumberGenerator, pack: BiomeContentPack) -> void:
	var ground := _height_at(center.x, center.y)
	for index: int in 3:
		var memory_slab := MeshInstance3D.new()
		memory_slab.name = "FrozenMemorySlab_%02d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.65, 2.8, 0.16)
		mesh.material = _standard_material(pack.accent_color.lightened(0.12 * float(index)), true)
		memory_slab.mesh = mesh
		memory_slab.position = Vector3(center.x + float(index - 1) * 1.35, ground + 1.45, center.y)
		memory_slab.rotation.y = rng.randf_range(-0.18, 0.18)
		root.add_child(memory_slab)


func _configure_generated_poi_content(
	root: WorldMysteryPOI,
	center: Vector2,
	coordinate: Vector2i,
	pack: BiomeContentPack,
	mystery: WorldMysteryDefinition
) -> void:
	var ground := _height_at(center.x, center.y)
	if mystery != null:
		root.configure(mystery, Vector3(center.x, ground, center.y))
		root.set_completed(_discovered_mystery_ids.has(mystery.id))
		root.discovered.connect(func(definition: WorldMysteryDefinition) -> void:
			_discovered_mystery_ids[definition.id] = true
			mystery_discovered.emit(definition)
		)
		root.event_started.connect(func(definition: WorldMysteryDefinition, instruction: String) -> void: mystery_event_started.emit(definition, instruction))
		root.event_failed.connect(func(definition: WorldMysteryDefinition, failure_text: String) -> void: mystery_event_failed.emit(definition, failure_text))
		root.event_progressed.connect(func(definition: WorldMysteryDefinition, progress: float, pressure: float) -> void: mystery_event_progressed.emit(definition, progress, pressure))
	if pack == null or pack.local_ingredient_ids.is_empty():
		return
	var ingredient_id := pack.local_ingredient_ids[abs(int(_chunk_seed(coordinate) + 17)) % pack.local_ingredient_ids.size()]
	var spawn_id := StringName("generated.%d.%d.%s" % [coordinate.x, coordinate.y, ingredient_id])
	if _collected_biome_ingredient_spawns.has(spawn_id):
		return
	var sample := GeneratedBiomeIngredient.new()
	sample.name = "LocalIngredient_%s" % String(ingredient_id).get_slice(".", 1)
	sample.configure(ingredient_id, spawn_id, pack.accent_color, pack.ecology_family)
	sample.set_meta(&"phase_id", _phase_definition.id if _phase_definition != null else &"phase.ordinary")
	var angle := float(abs(int(_chunk_seed(coordinate))) % 628) * 0.01
	var point := center + Vector2(cos(angle), sin(angle)) * 3.25
	sample.position = Vector3(point.x, _height_at(point.x, point.y) + 0.03, point.y)
	sample.harvested.connect(func(item: ItemInstance) -> void:
		_collected_biome_ingredient_spawns[spawn_id] = true
		biome_ingredient_harvested.emit(item)
	)
	sample.observed.connect(func(definition_id: StringName) -> void: biome_ingredient_observed.emit(definition_id))
	root.add_child(sample)
	root.register_reveal_node(sample)


func _build_altai_waymark(root: Node3D, center: Vector2, rng: RandomNumberGenerator) -> void:
	var ground := _height_at(center.x, center.y)
	var stone_material := _standard_material(Color("343b37"))
	var wood_material := _standard_material(Color("4d2c19"))
	var cloth_material := _standard_material(Color("9f3726"), true)
	cloth_material.emission_energy_multiplier = 0.38
	for index: int in 9:
		var angle := TAU * float(index) / 9.0 + rng.randf_range(-0.12, 0.12)
		var radius := rng.randf_range(1.25, 1.9)
		var stone := MeshInstance3D.new()
		stone.name = "CairnStone_%02d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(rng.randf_range(0.45, 0.82), rng.randf_range(0.28, 0.58), rng.randf_range(0.38, 0.72))
		stone.mesh = mesh
		stone.material_override = stone_material
		var point := center + Vector2(cos(angle), sin(angle)) * radius
		stone.position = Vector3(point.x, _height_at(point.x, point.y) + mesh.size.y * 0.42, point.y)
		stone.rotation = Vector3(rng.randf_range(-0.16, 0.16), -angle, rng.randf_range(-0.12, 0.12))
		root.add_child(stone)
	var marker := MeshInstance3D.new()
	marker.name = "WeatheredCedarMarker"
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.11
	marker_mesh.bottom_radius = 0.19
	marker_mesh.height = 4.8
	marker_mesh.radial_segments = 6
	marker.mesh = marker_mesh
	marker.material_override = wood_material
	marker.position = Vector3(center.x, ground + marker_mesh.height * 0.5, center.y)
	marker.rotation.z = rng.randf_range(-0.055, 0.055)
	root.add_child(marker)
	for side: int in [-1, 1]:
		var branch := MeshInstance3D.new()
		branch.name = "MarkerBranch_%d" % side
		var branch_mesh := CylinderMesh.new()
		branch_mesh.top_radius = 0.045
		branch_mesh.bottom_radius = 0.075
		branch_mesh.height = 1.45
		branch_mesh.radial_segments = 5
		branch.mesh = branch_mesh
		branch.material_override = wood_material
		branch.position = Vector3(center.x + float(side) * 0.52, ground + 3.35, center.y)
		branch.rotation.z = PI * 0.5 + float(side) * 0.22
		root.add_child(branch)
	for index: int in 5:
		var ribbon := MeshInstance3D.new()
		ribbon.name = "PrayerRibbon_%02d" % index
		var ribbon_mesh := QuadMesh.new()
		ribbon_mesh.size = Vector2(rng.randf_range(0.12, 0.2), rng.randf_range(0.55, 0.95))
		ribbon.mesh = ribbon_mesh
		ribbon.material_override = cloth_material
		ribbon.position = Vector3(center.x + rng.randf_range(-0.68, 0.68), ground + rng.randf_range(2.65, 3.55), center.y + 0.08)
		ribbon.rotation.y = rng.randf_range(-0.35, 0.35)
		ribbon.rotation.z = rng.randf_range(-0.18, 0.18)
		root.add_child(ribbon)
	var offering := MeshInstance3D.new()
	offering.name = "AbandonedFieldOffering"
	var offering_mesh := PrismMesh.new()
	offering_mesh.size = Vector3(0.8, 0.16, 0.52)
	offering.mesh = offering_mesh
	offering.material_override = _standard_material(Color("6e5840"))
	offering.position = Vector3(center.x + 0.75, ground + 0.13, center.y + 0.52)
	offering.rotation.y = rng.randf_range(-0.6, 0.6)
	root.add_child(offering)


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


func _accept_ecology_point(point: Vector2, layer: int, pack: BiomeContentPack) -> bool:
	if pack == null:
		return true
	# Offset noise fields prevent trees, stone and groundcover from becoming one
	# uniform procedural carpet. Each layer forms patches and leaves authored
	# negative space around the route and major compositions.
	var ecology_offset := float(pack.ecology_family) * 173.0
	var broad := _noise.get_noise_2d(point.x * 0.72 + ecology_offset, point.y * 0.72 - ecology_offset)
	var detail := _detail_noise.get_noise_2d(point.x * 0.38 - ecology_offset, point.y * 0.38 + ecology_offset)
	match layer:
		0: # Vegetation forms groves and deliberate clearings.
			var threshold := lerpf(0.08, -0.24, clampf(pack.vegetation_density / 1.6, 0.0, 1.0))
			return broad + detail * 0.28 > threshold
		1: # Geology traces different bands instead of shadowing the trees.
			return absf(broad * 0.7 - detail) > lerpf(0.34, 0.12, clampf(pack.geology_density / 1.8, 0.0, 1.0))
		_: # Groundcover bridges grove edges but preserves open sight lines.
			return broad * 0.62 + detail * 0.55 > -0.22


func _is_reserved(point: Vector2) -> bool:
	for exclusion_center: Vector2 in _decor_exclusion_centers:
		if point.distance_to(exclusion_center) < 7.2:
			return true
	if is_instance_valid(_target):
		var target_point := Vector2(_target.global_position.x, _target.global_position.z)
		if point.distance_to(target_point) < 14.0:
			return true
	if point.y < MIN_EXPEDITION_Z + 2.0:
		return true
	# The route is a readable valley and a playable movement lane, not a painted road.
	# Keep only its narrow walking core free; larger vegetation still frames both sides.
	if _distance_to_expedition_route(point) < 2.25:
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


func _route_center_x(z: float) -> float:
	var seed_phase := float(posmod(_run_seed, 997)) * 0.013
	var phase_offset := float(_phase_definition.order if _phase_definition != null else 0) * 0.73
	var wandering := sin(z * 0.018 + seed_phase) * 17.0 + sin(z * 0.0065 - seed_phase * 0.37 + phase_offset) * 9.0
	# Preserve the authored first departure from camp, then let the route become seed-specific.
	return wandering * smoothstep(42.0, 105.0, z)


func _distance_to_expedition_route(point: Vector2) -> float:
	return absf(point.x - _route_center_x(point.y))


func _should_place_landmark(coordinate: Vector2i, pack: BiomeContentPack) -> bool:
	var period := pack.landmark_period if pack != null else 7
	if posmod(coordinate.y - 2, period) != 0:
		return false
	var intended := _landmark_center_for_row(coordinate.y, pack)
	return coordinate.x == floori(intended.x / chunk_size)


func _should_place_ecology_composition(coordinate: Vector2i, pack: BiomeContentPack) -> bool:
	if pack == null or coordinate.y < 3:
		return false
	if posmod(coordinate.y - 3, pack.composition_period) != 0:
		return false
	# Story POIs keep a clean visual stage. Ecological compositions occupy the
	# quieter beats between them and make the route read as authored cadence.
	if _should_place_landmark_row(coordinate.y, pack):
		return false
	var intended := _composition_center_for_row(coordinate.y, pack)
	return coordinate.x == floori(intended.x / chunk_size)


func _composition_center_for_row(row: int, pack: BiomeContentPack) -> Vector2:
	var row_seed := _chunk_seed(Vector2i(73, row))
	var z_jitter := float(abs(row_seed) % 997) / 996.0
	var side := -1.0 if posmod(row + int(pack.ecology_family), 2) == 0 else 1.0
	var z := (float(row) + lerpf(0.28, 0.72, z_jitter)) * chunk_size
	var lateral := side * lerpf(6.2, 9.4, float(abs(row_seed / 1009) % 991) / 990.0)
	return Vector2(_route_center_x(z) + lateral, z)


func _landmark_center(coordinate: Vector2i, pack: BiomeContentPack) -> Vector2:
	if _should_place_landmark_row(coordinate.y, pack):
		return _landmark_center_for_row(coordinate.y, pack)
	return Vector2((float(coordinate.x) + 0.5) * chunk_size, (float(coordinate.y) + 0.5) * chunk_size)


func _should_place_landmark_row(row: int, pack: BiomeContentPack) -> bool:
	var period := pack.landmark_period if pack != null else 7
	return posmod(row - 2, period) == 0


func _landmark_center_for_row(row: int, _pack: BiomeContentPack) -> Vector2:
	var row_seed := _chunk_seed(Vector2i(0, row))
	var jitter_a := float(abs(row_seed) % 1009) / 1008.0
	var jitter_b := float(abs(row_seed / 1013) % 1019) / 1018.0
	var z := (float(row) + lerpf(0.34, 0.68, jitter_a)) * chunk_size
	var side := -1.0 if (abs(row_seed) % 2 == 0) else 1.0
	var lateral := side * lerpf(8.5, 13.5, jitter_b)
	return Vector2(_route_center_x(z) + lateral, z)


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


func _rebuild_presentation_layers() -> void:
	if is_instance_valid(_horizon_root):
		_horizon_root.queue_free()
	if is_instance_valid(_atmosphere):
		_atmosphere.queue_free()
	_horizon_root = Node3D.new()
	_horizon_root.name = "BiomeHorizon"
	add_child(_horizon_root)
	var pack := _get_content_pack()
	var ecology := pack.ecology_family if pack != null else BiomeContentPack.EcologyFamily.ALTAI_TAIGA
	if not is_instance_valid(_biome_ambience):
		_biome_ambience = BIOME_AMBIENCE.new() as AudioStreamPlayer
		_biome_ambience.name = "BiomeProceduralAmbience"
		add_child(_biome_ambience)
	_biome_ambience.call("configure", ecology, base_seed + _run_seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = base_seed * 97 + _run_seed * 53 + ecology * 101
	match ecology:
		BiomeContentPack.EcologyFamily.ALTAI_TAIGA:
			_build_mountain_horizon(rng, pack)
		BiomeContentPack.EcologyFamily.MYCELIAL_KARST:
			_build_fungal_horizon(rng, pack)
		_:
			_build_signature_horizon(rng, pack)
	_build_biome_atmosphere(pack)


func _build_mountain_horizon(rng: RandomNumberGenerator, pack: BiomeContentPack) -> void:
	var low := pack.ground_low if pack != null else Color(0.055, 0.15, 0.065)
	var high := pack.ground_high if pack != null else Color(0.28, 0.27, 0.12)
	for index in 16:
		var peak := MeshInstance3D.new()
		peak.name = "DistantRidge_%02d" % index
		var mesh := PrismMesh.new()
		var width := rng.randf_range(18.0, 31.0)
		var height := rng.randf_range(24.0, 46.0)
		mesh.size = Vector3(width, height, rng.randf_range(7.0, 13.0))
		mesh.material = _standard_material(low.lerp(high, rng.randf_range(0.08, 0.38)).darkened(0.34))
		peak.mesh = mesh
		var angle := TAU * float(index) / 16.0 + rng.randf_range(-0.08, 0.08)
		var radius := rng.randf_range(82.0, 105.0)
		peak.position = Vector3(cos(angle) * radius, height * 0.5, sin(angle) * radius)
		peak.rotation.y = -angle + PI * 0.5
		_horizon_root.add_child(peak)


func _build_fungal_horizon(rng: RandomNumberGenerator, pack: BiomeContentPack) -> void:
	var stem_mesh := BIOME_MESH_LIBRARY.create_fungus_stem()
	var cap_mesh := BIOME_MESH_LIBRARY.create_fungus_cap()
	_set_mesh_material(stem_mesh, _standard_material(Color(0.16, 0.045, 0.2)))
	_set_mesh_material(cap_mesh, _standard_material(pack.accent_color.darkened(0.42), true))
	for index in 13:
		var angle := TAU * float(index) / 13.0 + rng.randf_range(-0.12, 0.12)
		var radius := rng.randf_range(68.0, 96.0)
		var scale := rng.randf_range(2.8, 5.4)
		var stem := MeshInstance3D.new()
		stem.name = "DistantFungalStem_%02d" % index
		stem.mesh = stem_mesh
		stem.scale = Vector3(scale, scale, scale)
		stem.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		_horizon_root.add_child(stem)
		var cap := MeshInstance3D.new()
		cap.name = "DistantFungalCap_%02d" % index
		cap.mesh = cap_mesh
		cap.scale = Vector3(scale * rng.randf_range(1.0, 1.45), scale, scale * rng.randf_range(1.0, 1.45))
		cap.position = stem.position + Vector3(0.0, 4.15 * scale, 0.0)
		cap.rotation.y = rng.randf_range(0.0, TAU)
		_horizon_root.add_child(cap)


func _build_signature_horizon(rng: RandomNumberGenerator, pack: BiomeContentPack) -> void:
	var mesh: Mesh
	var count := 14
	var scale_low := 3.5
	var scale_high := 6.5
	var base_y := 3.0
	match pack.ecology_family:
		BiomeContentPack.EcologyFamily.CRIMSON_STEPPE:
			mesh = BIOME_MESH_LIBRARY.create_antler_crown()
			scale_low = 5.0
			scale_high = 9.0
			base_y = 5.0
		BiomeContentPack.EcologyFamily.GLACIAL_CIRQUE:
			mesh = BIOME_MESH_LIBRARY.create_crystal_cluster()
			scale_low = 2.4
			scale_high = 4.2
			base_y = 0.0
		BiomeContentPack.EcologyFamily.ASHEN_TUNDRA:
			mesh = BIOME_MESH_LIBRARY.create_ash_column()
			count = 18
			scale_low = 3.0
			scale_high = 7.0
			base_y = 0.0
		BiomeContentPack.EcologyFamily.MIRROR_WETLAND:
			mesh = BIOME_MESH_LIBRARY.create_wetland_shelf()
			count = 12
			scale_low = 5.5
			scale_high = 10.0
			base_y = 8.0
		BiomeContentPack.EcologyFamily.ROOT_CAVERN:
			mesh = BIOME_MESH_LIBRARY.create_root_loop()
			scale_low = 5.0
			scale_high = 8.5
			base_y = 10.0
		_:
			mesh = BIOME_MESH_LIBRARY.create_floating_strata()
			count = 16
			scale_low = 4.5
			scale_high = 9.0
			base_y = 12.0
	_set_mesh_material(mesh, _standard_material(pack.accent_color.darkened(0.48), pack.ecology_family != BiomeContentPack.EcologyFamily.ASHEN_TUNDRA))
	for index in count:
		var silhouette := MeshInstance3D.new()
		silhouette.name = "SignatureHorizon_%02d" % index
		silhouette.mesh = mesh
		var angle := TAU * float(index) / float(count) + rng.randf_range(-0.1, 0.1)
		var radius := rng.randf_range(72.0, 102.0)
		var scale := rng.randf_range(scale_low, scale_high)
		silhouette.scale = Vector3(scale * rng.randf_range(0.8, 1.25), scale, scale * rng.randf_range(0.75, 1.2))
		silhouette.position = Vector3(cos(angle) * radius, base_y + rng.randf_range(-2.0, 3.0), sin(angle) * radius)
		silhouette.rotation.y = rng.randf_range(0.0, TAU)
		_horizon_root.add_child(silhouette)


func _build_biome_atmosphere(pack: BiomeContentPack) -> void:
	_atmosphere = GPUParticles3D.new()
	_atmosphere.name = "BiomeAtmosphere"
	var ecology := pack.ecology_family if pack != null else BiomeContentPack.EcologyFamily.ALTAI_TAIGA
	_atmosphere.amount = 150
	_atmosphere.lifetime = 8.0
	_atmosphere.preprocess = 8.0
	_atmosphere.randomness = 0.72
	_atmosphere.visibility_aabb = AABB(Vector3(-32.0, -8.0, -32.0), Vector3(64.0, 20.0, 64.0))
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(27.0, 7.0, 27.0)
	process_material.direction = Vector3(0.2, 1.0, 0.12)
	process_material.spread = 42.0
	process_material.initial_velocity_min = 0.12
	process_material.initial_velocity_max = 0.58
	process_material.gravity = Vector3(0.08, 0.035, 0.04)
	process_material.scale_min = 0.45
	process_material.scale_max = 1.45
	match ecology:
		BiomeContentPack.EcologyFamily.CRIMSON_STEPPE:
			_atmosphere.amount = 105
			process_material.direction = Vector3(1.0, 0.25, 0.18)
			process_material.initial_velocity_min = 0.8
			process_material.initial_velocity_max = 2.4
			process_material.gravity = Vector3(0.35, 0.18, 0.0)
		BiomeContentPack.EcologyFamily.GLACIAL_CIRQUE:
			_atmosphere.amount = 240
			process_material.direction = Vector3(0.35, -1.0, 0.12)
			process_material.spread = 28.0
			process_material.initial_velocity_min = 0.5
			process_material.initial_velocity_max = 1.7
			process_material.gravity = Vector3(0.12, -0.48, 0.04)
		BiomeContentPack.EcologyFamily.ASHEN_TUNDRA:
			_atmosphere.amount = 210
			process_material.direction = Vector3(0.5, -0.42, 0.16)
			process_material.initial_velocity_min = 0.15
			process_material.initial_velocity_max = 0.72
			process_material.gravity = Vector3(0.08, -0.12, 0.02)
		BiomeContentPack.EcologyFamily.MIRROR_WETLAND:
			_atmosphere.amount = 120
			process_material.direction = Vector3(0.65, 0.05, 0.25)
			process_material.initial_velocity_min = 0.08
			process_material.initial_velocity_max = 0.38
			process_material.gravity = Vector3.ZERO
		BiomeContentPack.EcologyFamily.ROOT_CAVERN:
			_atmosphere.amount = 175
			process_material.direction = Vector3(0.05, 1.0, 0.05)
			process_material.initial_velocity_min = 0.3
			process_material.initial_velocity_max = 0.95
			process_material.gravity = Vector3(0.0, 0.16, 0.0)
		BiomeContentPack.EcologyFamily.HEART_PLATEAU:
			_atmosphere.amount = 190
			process_material.direction = Vector3(0.4, 0.65, -0.3)
			process_material.initial_velocity_min = 0.4
			process_material.initial_velocity_max = 1.35
			process_material.gravity = Vector3(0.0, 0.08, 0.0)
	_atmosphere.process_material = process_material
	var quad := QuadMesh.new()
	var altered := ecology != BiomeContentPack.EcologyFamily.ALTAI_TAIGA
	quad.size = Vector2(0.018, 0.018) if not altered else Vector2(0.028, 0.028)
	if ecology == BiomeContentPack.EcologyFamily.GLACIAL_CIRQUE:
		quad.size = Vector2(0.014, 0.055)
	elif ecology == BiomeContentPack.EcologyFamily.ASHEN_TUNDRA:
		quad.size = Vector2(0.016, 0.026)
	var particle_material := StandardMaterial3D.new()
	var color := Color(0.82, 0.66, 0.24, 0.38) if pack == null else pack.accent_color
	color.a = 0.38 if not altered else 0.72
	particle_material.albedo_color = color
	particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particle_material.emission_enabled = altered
	particle_material.emission = Color(color.r, color.g, color.b)
	particle_material.emission_energy_multiplier = 0.7
	quad.material = particle_material
	_atmosphere.draw_pass_1 = quad
	add_child(_atmosphere)


func _standard_material(color: Color, emission: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.48
	return material


func _ecology_motion_material(color: Color, pack: BiomeContentPack, height_response: float, emission_strength: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ECOLOGY_MOTION_SHADER
	material.set_shader_parameter(&"base_color", color)
	material.set_shader_parameter(&"motion_strength", pack.ecology_motion_strength if pack != null else 0.08)
	material.set_shader_parameter(&"motion_speed", pack.ecology_motion_speed if pack != null else 1.0)
	material.set_shader_parameter(&"height_response", height_response)
	material.set_shader_parameter(&"emission_strength", emission_strength)
	return material


func _set_mesh_material(mesh: Mesh, material: Material) -> void:
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = material
	else:
		for surface_index in mesh.get_surface_count():
			mesh.surface_set_material(surface_index, material)


func _cached_biome_mesh(key: StringName, method: StringName, arguments: Array = []) -> Mesh:
	if not _generated_mesh_cache.has(key):
		_generated_mesh_cache[key] = _mesh_library.callv(method, arguments) as Mesh
	return _generated_mesh_cache[key]


func _build_terrain_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform float metamorphosis : hint_range(0.0, 1.0) = 0.0;
uniform vec3 phase_low : source_color = vec3(0.025, 0.16, 0.32);
uniform vec3 phase_high : source_color = vec3(0.82, 0.025, 0.7);
varying float pulse;
varying vec3 terrain_position;
varying float terrain_slope;
float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}
void vertex() {
	terrain_position = VERTEX;
	terrain_slope = 1.0 - abs(NORMAL.y);
	float wave_a = sin(VERTEX.x * 0.075 + TIME * 0.65);
	float wave_b = cos(VERTEX.z * 0.061 - TIME * 0.48);
	pulse = wave_a * wave_b;
	VERTEX.y += pulse * 0.32 * metamorphosis;
}
void fragment() {
	vec3 mundane = COLOR.rgb;
	float broad = 0.5 + 0.5 * sin((terrain_position.x + terrain_position.z) * 0.055 + pulse * 1.4);
	float cells = hash21(floor(terrain_position.xz * 0.72));
	float grain = mix(0.86, 1.13, cells);
	float slope_mask = smoothstep(0.1, 0.46, terrain_slope);
	vec3 altered_palette = mix(phase_low, phase_high, broad * 0.72 + cells * 0.28);
	vec3 altered = mix(mundane, altered_palette, 0.72);
	vec3 ground = mix(mundane, altered, metamorphosis);
	ground *= grain;
	ground = mix(ground, ground * 0.58 + phase_high * 0.16, slope_mask * 0.62);
	ALBEDO = ground;
	ROUGHNESS = mix(0.94, 0.72, metamorphosis) - cells * 0.08;
	EMISSION = altered_palette * metamorphosis * (0.1 + max(pulse, 0.0) * 0.22) * (1.0 - slope_mask * 0.55);
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
