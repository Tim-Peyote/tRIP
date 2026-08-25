class_name ExpeditionTerrain
extends StaticBody3D

signal mystery_discovered(definition: WorldMysteryDefinition)
signal mystery_event_started(definition: WorldMysteryDefinition, instruction: String)
signal mystery_event_failed(definition: WorldMysteryDefinition, failure_text: String)
signal mystery_event_progressed(definition: WorldMysteryDefinition, progress: float, pressure: float)
signal biome_ingredient_harvested(item: ItemInstance)
signal biome_ingredient_observed(definition_id: StringName)
signal authored_encounter_completed(clue_id: StringName, title: String, text: String)

const PHASE_ORDINARY: StringName = &"ordinary"
const PHASE_MYCELIAL: StringName = &"mycelial"
const MIN_EXPEDITION_Z: float = 5.8
const BIOME_MESH_LIBRARY = preload("res://world/terrain/biome_mesh_library.gd")
const TERRAIN_CHUNK_MESH_BUILDER = preload("res://world/terrain/terrain_chunk_mesh_builder.gd")
const AUTHORED_NATURE_ASSET_LIBRARY = preload("res://world/terrain/authored_nature_asset_library.gd")
const BIOME_AMBIENCE = preload("res://presentation/audio/biome_procedural_ambience.gd")
const ECOLOGY_MOTION_SHADER = preload("res://presentation/shaders/ecology_motion.gdshader")
const ILYA_ROOT_ECHO = preload("res://features/npcs/ilya_root_echo.tscn")

enum LandscapeZone { SHELTER_EDGE, RIVER_VALLEY, DENSE_FOREST, HIGHLAND, ALPINE, BASIN, BOUNDARY }

const REGION_STREAM_MARGIN: float = 1.12
const REGION_FAILSAFE_RATIO: float = 1.045

@export_range(16.0, 64.0, 1.0) var chunk_size: float = 30.0
@export_range(9, 49, 2) var chunk_resolution: int = 25
@export_range(1, 4, 1) var active_radius: int = 2
@export_range(2, 6, 1) var visual_radius: int = 3
@export_range(1, 3, 1) var collision_radius: int = 1
@export_range(7, 25, 2) var distant_chunk_resolution: int = 13
@export_range(7, 25, 2) var collision_resolution: int = 25
@export_range(1, 4, 1) var chunks_per_frame: int = 1
@export_range(1.0, 12.0, 0.5, "suffix:ms") var generation_budget_ms: float = 4.0
@export var base_seed: int = 61937

var _run_seed: int = 0
var _world_phase: StringName = PHASE_ORDINARY
var _phase_definition: WorldPhaseDefinition
var _phase_amount: float = 0.0
var _target: Node3D
var _last_center := Vector2i(999999, 999999)
var _chunks: Dictionary[Vector2i, StaticBody3D] = {}
var _pending: Array[Vector2i] = []
var _desired_tiers: Dictionary[Vector2i, int] = {}
var _noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _terrain_material: ShaderMaterial
var _horizon_root: Node3D
var _atmosphere: GPUParticles3D
var _generated_mesh_cache: Dictionary[StringName, Mesh] = {}
var _mesh_library: RefCounted = BIOME_MESH_LIBRARY.new()
var _authored_nature_library: RefCounted = AUTHORED_NATURE_ASSET_LIBRARY.new()
var _biome_ambience: AudioStreamPlayer
var _decor_exclusion_centers: Array[Vector2] = []
var _collected_biome_ingredient_spawns: Dictionary[StringName, bool] = {}
var _discovered_mystery_ids: Dictionary[StringName, bool] = {}
var _last_safe_target_position := Vector3(0.0, 1.0, 15.0)
var _safe_position_tick: float = 0.0


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
		# Beacon colour is intentionally a rare navigation accent. Feeding it into the
		# entire landscape made every altered world read as one emissive colour wash.
		_terrain_material.set_shader_parameter(&"phase_high", definition.stone_high)
		_sync_terrain_surface_palette(definition)
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


func get_pending_chunk_count() -> int:
	return _pending.size()


func get_collision_chunk_count() -> int:
	var count := 0
	for body: StaticBody3D in _chunks.values():
		if body.get_node_or_null("Collision") != null:
			count += 1
	return count


func get_distant_chunk_count() -> int:
	var count := 0
	for body: StaticBody3D in _chunks.values():
		if int(body.get_meta(&"terrain_detail_tier", 0)) == 0:
			count += 1
	return count


func get_generated_mesh_cache_size() -> int:
	return _generated_mesh_cache.size()


func get_ambience_ecology_family() -> int:
	return int(_biome_ambience.get("ecology_family")) if is_instance_valid(_biome_ambience) else -1


func is_biome_ambience_active() -> bool:
	return bool(_biome_ambience.call("is_expedition_active")) if is_instance_valid(_biome_ambience) else false


func get_biome_ambience_layer_count() -> int:
	if not is_instance_valid(_biome_ambience):
		return 0
	var count := 1
	for child: Node in _biome_ambience.get_children():
		if child is AudioStreamPlayer:
			count += 1
	return count


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


func _process(delta: float) -> void:
	if is_instance_valid(_target):
		_recover_target_below_surface()
		_update_region_failsafe(delta)
		var expedition_visible := _target.global_position.z >= MIN_EXPEDITION_Z
		if is_instance_valid(_horizon_root):
			_horizon_root.visible = expedition_visible
		if is_instance_valid(_atmosphere):
			_atmosphere.visible = expedition_visible
			_atmosphere.global_position = _target.global_position + Vector3(0.0, 4.0, 0.0)
		if is_instance_valid(_biome_ambience):
			_biome_ambience.call("set_expedition_active", expedition_visible)
		var center := _chunk_coordinate(_target.global_position)
		if center != _last_center:
			_refresh_chunks(_target.global_position, true)
	var generation_started := Time.get_ticks_usec()
	var processed := 0
	while processed < chunks_per_frame and not _pending.is_empty():
		var coordinate: Vector2i = _pending.pop_front()
		if not _desired_tiers.has(coordinate):
			continue
		var desired_tier: int = _desired_tiers[coordinate]
		if _chunks.has(coordinate):
			_apply_chunk_tier(_chunks[coordinate], coordinate, desired_tier)
		else:
			_build_chunk(coordinate, desired_tier)
		processed += 1
		if processed > 0 and float(Time.get_ticks_usec() - generation_started) >= generation_budget_ms * 1000.0:
			break


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
	var resolved_visual_radius := maxi(visual_radius, maxi(active_radius, collision_radius))
	for z_offset in range(-resolved_visual_radius, resolved_visual_radius + 1):
		for x_offset in range(-resolved_visual_radius, resolved_visual_radius + 1):
			offsets.append(Vector2i(x_offset, z_offset))
	offsets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.length_squared() < b.length_squared())
	_pending.clear()
	_desired_tiers.clear()
	for offset: Vector2i in offsets:
		var coordinate := center + offset
		if not _chunk_intersects_region(coordinate):
			continue
		var tier := _detail_tier_for_offset(offset)
		desired[coordinate] = true
		_desired_tiers[coordinate] = tier
		if not _chunks.has(coordinate) or int(_chunks[coordinate].get_meta(&"terrain_detail_tier", -1)) != tier:
			_pending.append(coordinate)
	for coordinate: Vector2i in _chunks.keys():
		if not desired.has(coordinate):
			_retire_chunk(_chunks[coordinate])
			_chunks.erase(coordinate)
	if immediate_center:
		# Never expose the player to an asynchronously generated seam. Build the
		# complete 3x3 physics neighbourhood before returning; only decoration and
		# distant horizon chunks are allowed to stream over later frames.
		for z_offset in range(-collision_radius, collision_radius + 1):
			for x_offset in range(-collision_radius, collision_radius + 1):
				var coordinate := center + Vector2i(x_offset, z_offset)
				if not _desired_tiers.has(coordinate):
					continue
				var desired_tier := int(_desired_tiers.get(coordinate, 2))
				_pending.erase(coordinate)
				if not _chunks.has(coordinate):
					_build_chunk(coordinate, desired_tier)
				elif int(_chunks[coordinate].get_meta(&"terrain_detail_tier", -1)) != desired_tier:
					_apply_chunk_tier(_chunks[coordinate], coordinate, desired_tier)


func _recover_target_below_surface() -> void:
	if not _target is CharacterBody3D:
		return
	var terrain_height := _height_at(_target.global_position.x, _target.global_position.z)
	if _target.global_position.y >= terrain_height - 1.0:
		return
	var safe_position := _target.global_position
	safe_position.y = terrain_height + 0.08
	_target.global_position = safe_position
	(_target as CharacterBody3D).velocity.y = 0.0
	(_target as CharacterBody3D).apply_floor_snap()


func _update_region_failsafe(delta: float) -> void:
	if not _target is CharacterBody3D:
		return
	_safe_position_tick += delta
	var ratio := get_region_ratio(Vector2(_target.global_position.x, _target.global_position.z))
	if ratio <= 0.86 and _safe_position_tick >= 0.5:
		_safe_position_tick = 0.0
		_last_safe_target_position = _target.global_position
		return
	if ratio <= REGION_FAILSAFE_RATIO:
		return
	var safe_position := _last_safe_target_position
	safe_position.y = _height_at(safe_position.x, safe_position.z) + 0.12
	_target.global_position = safe_position
	(_target as CharacterBody3D).velocity = Vector3.ZERO
	(_target as CharacterBody3D).apply_floor_snap()


func get_region_ratio(point: Vector2) -> float:
	var pack := _get_content_pack()
	var half_width := pack.region_half_width if pack != null else 410.0
	var length := pack.region_length if pack != null else 920.0
	var south := pack.region_south if pack != null else -120.0
	var center := Vector2(0.0, south + length * 0.5)
	var normalized := Vector2(absf(point.x - center.x) / half_width, absf(point.y - center.y) / (length * 0.5))
	# A superellipse keeps broad playable valleys while still producing a natural,
	# irregular mountain ring instead of a visible square or perfect circular wall.
	return pow(pow(normalized.x, 2.4) + pow(normalized.y, 2.4), 1.0 / 2.4)


func is_inside_playable_region(world_position: Vector3, margin: float = 0.0) -> bool:
	return get_region_ratio(Vector2(world_position.x, world_position.z)) <= 1.0 + margin


func get_route_end_z() -> float:
	var pack := _get_content_pack()
	var length := pack.region_length if pack != null else 920.0
	var south := pack.region_south if pack != null else -120.0
	return south + length * 0.89


func get_environment_context(world_position: Vector3) -> Dictionary:
	var point := Vector2(world_position.x, world_position.z)
	var pack := _get_content_pack()
	var ratio := get_region_ratio(point)
	var height := _height_at(point.x, point.y)
	var route_distance := _distance_to_expedition_route(point)
	var patch := _noise.get_noise_2d(point.x * 0.61 + 311.0, point.y * 0.61 - 127.0)
	var moisture_noise := _detail_noise.get_noise_2d(point.x * 0.24 - 71.0, point.y * 0.24 + 193.0)
	var highland_bias := pack.highland_bias if pack != null else 0.8
	var lowland_moisture := pack.lowland_moisture if pack != null else 0.45
	var altitude := clampf((height + 4.0) / maxf(24.0, 34.0 / maxf(highland_bias, 0.2)), 0.0, 1.0)
	var moisture := clampf(lowland_moisture + moisture_noise * 0.28 - altitude * 0.22, 0.0, 1.0)
	var exposure := clampf(0.36 + altitude * 0.72 + absf(patch) * 0.24, 0.0, 1.0)
	var zone := LandscapeZone.DENSE_FOREST
	if point.y < 58.0:
		zone = LandscapeZone.SHELTER_EDGE
	elif ratio >= (pack.boundary_inner_ratio if pack != null else 0.78):
		zone = LandscapeZone.BOUNDARY
	elif altitude >= 0.78:
		zone = LandscapeZone.ALPINE
	elif altitude >= 0.53 or patch > 0.46:
		zone = LandscapeZone.HIGHLAND
	elif moisture >= 0.72 and (height < 3.5 or moisture_noise > 0.42):
		zone = LandscapeZone.BASIN
	elif route_distance <= (pack.route_width * 1.7 if pack != null else 9.5):
		zone = LandscapeZone.RIVER_VALLEY
	var zone_names: Array[StringName] = [&"shelter_edge", &"river_valley", &"dense_forest", &"highland", &"alpine", &"basin", &"boundary"]
	var snow_allowed := zone in [LandscapeZone.HIGHLAND, LandscapeZone.ALPINE, LandscapeZone.BOUNDARY]
	if pack != null and pack.ecology_family in [BiomeContentPack.EcologyFamily.GLACIAL_CIRQUE, BiomeContentPack.EcologyFamily.ASHEN_TUNDRA]:
		snow_allowed = true
	return {
		"zone": zone,
		"zone_id": zone_names[zone],
		"region_ratio": ratio,
		"height": height,
		"altitude": altitude,
		"moisture": moisture,
		"exposure": exposure,
		"can_snow": snow_allowed,
		"forest_shelter": 0.72 if zone == LandscapeZone.DENSE_FOREST else (0.38 if zone == LandscapeZone.RIVER_VALLEY else 0.0),
	}


func _chunk_intersects_region(coordinate: Vector2i) -> bool:
	var start := Vector2(float(coordinate.x) * chunk_size, float(coordinate.y) * chunk_size)
	var end := start + Vector2.ONE * chunk_size
	for point: Vector2 in [start, Vector2(end.x, start.y), Vector2(start.x, end.y), end, (start + end) * 0.5]:
		if get_region_ratio(point) <= REGION_STREAM_MARGIN:
			return true
	return false


func _detail_tier_for_offset(offset: Vector2i) -> int:
	var distance := maxi(absi(offset.x), absi(offset.y))
	if distance <= collision_radius:
		return 2
	if distance <= active_radius:
		return 1
	return 0


func _chunk_coordinate(world_position: Vector3) -> Vector2i:
	return Vector2i(floori(world_position.x / chunk_size), floori(world_position.z / chunk_size))


func _build_chunk(coordinate: Vector2i, detail_tier: int = 2) -> void:
	var body := StaticBody3D.new()
	body.name = "LandscapeChunk_%d_%d" % [coordinate.x, coordinate.y]
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta(&"landscape_chunk", true)
	body.set_meta(&"chunk_coordinate", coordinate)
	body.set_meta(&"terrain_detail_tier", detail_tier)
	add_child(body)
	var mesh := _build_chunk_mesh(coordinate, chunk_resolution if detail_tier >= 1 else distant_chunk_resolution)
	if mesh.get_surface_count() > 0:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Terrain"
		mesh_instance.mesh = mesh
		mesh_instance.material_override = _terrain_material
		body.add_child(mesh_instance)
		if detail_tier >= 2:
			_add_chunk_collision(body, coordinate, mesh)
	if detail_tier >= 1:
		_build_chunk_decor(body, coordinate)
	_chunks[coordinate] = body


func _build_chunk_mesh(coordinate: Vector2i, resolution: int = -1, include_vertex_colors: bool = true) -> ArrayMesh:
	if resolution < 0:
		resolution = chunk_resolution
	return TERRAIN_CHUNK_MESH_BUILDER.build(
		coordinate,
		chunk_size,
		resolution,
		-INF,
		_height_at,
		_terrain_color,
		include_vertex_colors,
	)


func _apply_chunk_tier(body: StaticBody3D, coordinate: Vector2i, detail_tier: int) -> void:
	var previous_tier := int(body.get_meta(&"terrain_detail_tier", -1))
	if previous_tier == detail_tier:
		return
	var terrain := body.get_node_or_null("Terrain") as MeshInstance3D
	if terrain != null and (previous_tier == 0) != (detail_tier == 0):
		terrain.mesh = _build_chunk_mesh(coordinate, chunk_resolution if detail_tier >= 1 else distant_chunk_resolution)
	var collision := body.get_node_or_null("Collision") as CollisionShape3D
	if detail_tier >= 2 and collision == null:
		_add_chunk_collision(body, coordinate, terrain.mesh if terrain != null else null)
	elif detail_tier < 2 and collision != null:
		body.remove_child(collision)
		collision.queue_free()
	if previous_tier < 1 and detail_tier >= 1:
		_build_chunk_decor(body, coordinate)
	elif previous_tier >= 1 and detail_tier < 1:
		for child: Node in body.get_children():
			if child.name == "Terrain" or child.name == "Collision":
				continue
			body.remove_child(child)
			child.queue_free()
	body.set_meta(&"terrain_detail_tier", detail_tier)


func _add_chunk_collision(body: StaticBody3D, coordinate: Vector2i, render_mesh: Mesh) -> void:
	var collision_mesh: Mesh = render_mesh
	if collision_resolution != chunk_resolution or collision_mesh == null:
		collision_mesh = _build_chunk_mesh(coordinate, collision_resolution, false)
	if collision_mesh == null or collision_mesh.get_surface_count() == 0:
		return
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var terrain_shape := collision_mesh.create_trimesh_shape()
	# Runtime terrain must remain walkable even when a generated triangle strip
	# changes winding at a chunk seam. The prototype floor previously concealed
	# this by catching the player underneath the streamed surface.
	if terrain_shape is ConcavePolygonShape3D:
		(terrain_shape as ConcavePolygonShape3D).backface_collision = true
	collision.shape = terrain_shape
	body.add_child(collision)


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
				# Preserve broad glacial facets without quantising the whole landscape
				# into stacked slabs that expose ugly vertical plates at chunk LODs.
				var faceted_height := floorf(height * 0.34) / 0.34
				height = lerpf(height, faceted_height, 0.18)
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
	var route_width := pack.route_width if pack != null else 5.5
	var route_influence := 1.0 - smoothstep(route_width, route_width * 3.1, route_distance)
	route_influence *= 1.0 - smoothstep(get_route_end_z() - 55.0, get_route_end_z() + 8.0, z)
	var authored_route_blend := smoothstep(52.0, 84.0, z)
	var route_seed_phase := float(posmod(_run_seed, 997)) * 0.013
	var vista_period := float(pack.vista_period_chunks if pack != null else 6) * chunk_size
	var route_grade := sin(z * TAU / vista_period + route_seed_phase) * 3.1 * (pack.route_relief_scale if pack != null else 1.0)
	route_grade += sin(z * TAU / (vista_period * 2.35) - route_seed_phase * 0.4) * 1.45
	var target_route_height := minf(route_grade, height - 2.5)
	height = lerpf(height - route_influence * 2.2, target_route_height, route_influence * authored_route_blend * 0.78)
	var terrain_coordinate := Vector2i(floori(x / chunk_size), floori(z / chunk_size))
	if _should_place_landmark(terrain_coordinate, pack):
		var landmark_center := _landmark_center(terrain_coordinate, pack)
		if landmark_center.y >= MIN_EXPEDITION_Z + 2.0:
			var landmark_height := _noise.get_noise_2d(landmark_center.x, landmark_center.y) * 5.2 * elevation_scale
			height = _blend_disc(height, point, landmark_center, 9.5, landmark_height)
	height += _boundary_height_offset(point, pack)
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


func _boundary_height_offset(point: Vector2, pack: BiomeContentPack) -> float:
	var inner_ratio := pack.boundary_inner_ratio if pack != null else 0.78
	var boundary_height := pack.boundary_height if pack != null else 48.0
	var ratio := get_region_ratio(point)
	var rise := smoothstep(inner_ratio, 1.015, ratio)
	if rise <= 0.0:
		return 0.0
	var family := pack.boundary_family if pack != null else BiomeContentPack.BoundaryFamily.MOUNTAIN_RING
	var seed_phase := float(posmod(_run_seed, 8191)) * 0.0017
	var broken_ridge := absf(_detail_noise.get_noise_2d(point.x * 0.31 + 611.0, point.y * 0.31 - 277.0))
	var long_fold := 0.5 + 0.5 * sin(atan2(point.y, point.x) * 7.0 + seed_phase + ratio * 19.0)
	var silhouette := lerpf(0.72, 1.18, broken_ridge * 0.68 + long_fold * 0.32)
	match family:
		BiomeContentPack.BoundaryFamily.KARST_WALL:
			silhouette *= 0.82 + pow(broken_ridge, 2.0) * 0.75
		BiomeContentPack.BoundaryFamily.RED_ESCARPMENT:
			silhouette = floorf(silhouette * 4.0) / 4.0 + 0.18
		BiomeContentPack.BoundaryFamily.ICE_CIRQUE:
			silhouette *= 0.9 + absf(sin(point.x * 0.043 + point.y * 0.031)) * 0.52
		BiomeContentPack.BoundaryFamily.ASH_RIDGE:
			silhouette *= 0.78 + long_fold * 0.34
		BiomeContentPack.BoundaryFamily.MARSH_BLUFF:
			silhouette = 0.72 + floorf(broken_ridge * 3.0) * 0.12
		BiomeContentPack.BoundaryFamily.ROOT_RAMPART:
			silhouette *= 0.82 + absf(sin(point.x * 0.071 - point.y * 0.047)) * 0.48
		BiomeContentPack.BoundaryFamily.FRACTURED_PLATEAU:
			silhouette *= 1.16 if broken_ridge >= 0.48 else 0.74
	return pow(rise, 1.62) * boundary_height * silhouette


func _terrain_color(point: Vector2, height: float, slope: float) -> Color:
	var pack := _get_content_pack()
	var ground_low := pack.ground_low if pack != null else Color(0.105, 0.205, 0.085)
	var ground_high := pack.ground_high if pack != null else Color(0.31, 0.29, 0.13)
	var color := ground_low.lerp(ground_high, clampf((height + 3.0) / 15.0, 0.0, 1.0))
	var region_ratio := get_region_ratio(point)
	var vegetation_patch := _noise.get_noise_2d(point.x * 0.61 + 311.0, point.y * 0.61 - 127.0)
	var moisture_patch := _detail_noise.get_noise_2d(point.x * 0.24 - 71.0, point.y * 0.24 + 193.0)
	var highland_mask := smoothstep(5.0, 18.0, height)
	var basin_mask := (1.0 - smoothstep(0.5, 5.0, height)) * smoothstep(0.2, 0.72, moisture_patch * 0.5 + 0.5)
	color = color.lerp(ground_low.darkened(0.16), smoothstep(0.18, 0.62, vegetation_patch) * (1.0 - highland_mask) * 0.34)
	color = color.lerp(ground_low.lerp(Color(0.08, 0.16, 0.14), 0.28).darkened(0.12), basin_mask * 0.42)
	color = color.lerp(ground_high.lightened(0.1), highland_mask * 0.34)
	if pack != null:
		color = color.lerp(pack.ground_high.darkened(0.08), smoothstep(pack.boundary_inner_ratio, 1.0, region_ratio) * 0.58)
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
	var center_position := Vector3((float(coordinate.x) + 0.5) * chunk_size, 0.0, (float(coordinate.y) + 0.5) * chunk_size)
	var zone := int(get_environment_context(center_position).get("zone", LandscapeZone.DENSE_FOREST))
	var tree_zone_scale := 1.0
	var rock_zone_scale := 1.0
	var ground_zone_scale := 1.0
	match zone:
		LandscapeZone.DENSE_FOREST:
			tree_zone_scale = 1.38
			rock_zone_scale = 0.78
			ground_zone_scale = 1.3
		LandscapeZone.RIVER_VALLEY, LandscapeZone.BASIN:
			tree_zone_scale = 0.78
			rock_zone_scale = 0.68
			ground_zone_scale = 1.42
		LandscapeZone.HIGHLAND:
			tree_zone_scale = 0.58
			rock_zone_scale = 1.42
			ground_zone_scale = 0.72
		LandscapeZone.ALPINE:
			tree_zone_scale = 0.22
			rock_zone_scale = 1.7
			ground_zone_scale = 0.38
		LandscapeZone.BOUNDARY:
			tree_zone_scale = 0.34
			rock_zone_scale = 1.85
			ground_zone_scale = 0.42
	var has_landmark := _should_place_landmark(coordinate, pack)
	var landmark_center := _landmark_center(coordinate, pack)
	_decor_exclusion_centers.clear()
	if has_landmark and not _is_reserved(landmark_center):
		_decor_exclusion_centers.append(landmark_center)
	var procedural_tree_budget := 10.5 if pack != null and pack.ecology_family == BiomeContentPack.EcologyFamily.ALTAI_TAIGA else 16.0
	_add_tree_multimeshes(body, coordinate, rng, maxi(2, roundi(procedural_tree_budget * vegetation_density * tree_zone_scale)))
	_add_rock_multimesh(body, coordinate, rng, maxi(2, roundi(10.0 * geology_density * rock_zone_scale)))
	_add_groundcover_multimesh(body, coordinate, rng, maxi(4, roundi(34.0 * vegetation_density * ground_zone_scale)))
	_add_zone_accent_cluster(body, coordinate, rng, pack, zone)
	if pack != null and pack.ecology_family == BiomeContentPack.EcologyFamily.ALTAI_TAIGA:
		_add_authored_taiga_details(body, coordinate, rng)
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


func _add_authored_taiga_details(body: Node3D, coordinate: Vector2i, rng: RandomNumberGenerator) -> void:
	# One authored hero accent per family is enough to break up the procedural
	# silhouettes. Repeating imported scenes here duplicated hundreds of separate
	# draw objects already represented by the tree/rock/groundcover MultiMeshes.
	var chunk_center := Vector3((float(coordinate.x) + 0.5) * chunk_size, 0.0, (float(coordinate.y) + 0.5) * chunk_size)
	var zone := int(get_environment_context(chunk_center).get("zone", LandscapeZone.DENSE_FOREST))
	var families: Array[StringName] = [&"tall_pine", &"round_pine", &"forest_floor", &"rock", &"fungi"]
	match zone:
		LandscapeZone.RIVER_VALLEY, LandscapeZone.BASIN:
			families = [&"round_pine", &"young_pine", &"grass_cluster", &"forest_floor", &"fungi"]
		LandscapeZone.HIGHLAND, LandscapeZone.ALPINE:
			families = [&"tall_pine", &"young_pine", &"rock", &"rock", &"grass_cluster"]
		LandscapeZone.BOUNDARY:
			families = [&"tall_pine", &"rock", &"rock", &"young_pine", &"forest_floor"]
	var accent_count := 3 if zone in [LandscapeZone.DENSE_FOREST, LandscapeZone.RIVER_VALLEY, LandscapeZone.BASIN] else 2
	var family_offset := absi(_chunk_seed(coordinate)) % families.size()
	for selection_index in accent_count:
		var family_index := posmod(family_offset + selection_index * 2, families.size())
		var family := families[family_index]
		var point := Vector2.ZERO
		var accepted := false
		for _attempt in 8:
			point = _random_chunk_point(coordinate, rng)
			var ecology_layer := 1 if family == &"rock" else (2 if family in [&"fungi", &"forest_floor", &"grass_cluster"] else 0)
			if not _is_reserved(point) and _accept_ecology_point(point, ecology_layer, _get_content_pack()):
				accepted = true
				break
		if not accepted:
			continue
		var variant: int = absi(int(_chunk_seed(coordinate)) + family_index * 7919)
		var instance := _authored_nature_library.call("instantiate_variant", family, variant) as Node3D
		if instance == null:
			continue
		var scale_value := rng.randf_range(0.82, 1.28)
		if family == &"tall_pine":
			scale_value = rng.randf_range(1.05, 1.55)
		elif family == &"round_pine":
			scale_value = rng.randf_range(0.9, 1.35)
		elif family == &"rock":
			scale_value = rng.randf_range(0.65, 1.35)
		elif family == &"fungi":
			scale_value = rng.randf_range(0.55, 0.95)
		elif family == &"young_pine":
			scale_value = rng.randf_range(0.8, 1.35)
		elif family == &"grass_cluster":
			scale_value = rng.randf_range(0.7, 1.25)
		instance.position = Vector3(point.x, _height_at(point.x, point.y), point.y)
		instance.rotation.y = rng.randf_range(0.0, TAU)
		instance.scale *= scale_value
		body.add_child(instance)


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
	var secondary_crown: Mesh
	var crown_layers := 2
	var size_low := 0.75
	var size_high := 1.65
	match family:
		BiomeContentPack.VegetationFamily.CEDAR_FIR:
			trunk = _cached_biome_mesh(&"taiga_trunk", "create_taiga_trunk")
			trunk_height = 5.8
			trunk_has_base_origin = true
			crown = _cached_biome_mesh(&"conifer_crown", "create_conifer_crown")
			secondary_crown = _cached_biome_mesh(&"conifer_crown_windformed", "create_conifer_crown_windformed")
			crown_layers = 1
		BiomeContentPack.VegetationFamily.GIANT_FUNGI:
			trunk = _cached_biome_mesh(&"fungus_stem", "create_fungus_stem")
			trunk_height = 5.4
			trunk_has_base_origin = true
			crown = _cached_biome_mesh(&"fungus_cap", "create_fungus_cap")
			secondary_crown = _cached_biome_mesh(&"fungus_cap_bell", "create_fungus_cap_bell")
			trunk_color = Color(0.3, 0.18, 0.32)
			crown_layers = 1
		BiomeContentPack.VegetationFamily.ANTLER_LARCH:
			trunk = _cached_biome_mesh(&"taiga_trunk", "create_taiga_trunk")
			trunk_height = 5.8
			trunk_has_base_origin = true
			crown = _cached_biome_mesh(&"antler_crown", "create_antler_crown")
			secondary_crown = _cached_biome_mesh(&"antler_crown_swept", "create_antler_crown_swept")
			trunk_color = Color(0.16, 0.018, 0.012)
			crown_layers = 1
		BiomeContentPack.VegetationFamily.ICE_LICHEN:
			crown = _cached_biome_mesh(&"crystal_cluster", "create_crystal_cluster")
			secondary_crown = _cached_biome_mesh(&"ice_lattice", "create_ice_lattice")
			trunk_color = Color(0.08, 0.28, 0.4)
			crown_layers = 1
			trunk_shape.height = 3.6
			trunk_height = 3.6
		BiomeContentPack.VegetationFamily.BURNT_SNAGS:
			trunk = _cached_biome_mesh(&"taiga_trunk", "create_taiga_trunk")
			trunk_height = 5.8
			trunk_has_base_origin = true
			crown = _cached_biome_mesh(&"burnt_crown", "create_burnt_crown")
			secondary_crown = _cached_biome_mesh(&"burnt_crown_fork", "create_burnt_crown_fork")
			trunk_color = Color(0.035, 0.028, 0.025)
			crown_layers = 1
			size_low = 0.62
		BiomeContentPack.VegetationFamily.REED_ISLANDS:
			crown = _cached_biome_mesh(&"reed_head", "create_reed_head")
			secondary_crown = _cached_biome_mesh(&"reed_fan", "create_reed_fan")
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
			secondary_crown = _cached_biome_mesh(&"root_spire", "create_root_spire")
			trunk_shape.top_radius = 0.42
			trunk_shape.bottom_radius = 0.72
			trunk_color = Color(0.22, 0.07, 0.018)
			crown_layers = 2
		_:
			crown = _cached_biome_mesh(&"heart_loop", "create_heart_loop")
			secondary_crown = _cached_biome_mesh(&"heart_branch", "create_heart_branch")
			trunk_color = Color(0.08, 0.12, 0.28)
			crown_layers = 3
	_set_mesh_material(trunk, _standard_material(trunk_color))
	var crown_low := _phase_definition.canopy_low if _phase_definition != null else Color(0.055, 0.24, 0.075)
	_set_mesh_material(crown, _ecology_motion_material(crown_low, pack, 0.34, 0.14 if _is_altered_phase() else 0.0))
	_set_mesh_material(secondary_crown, _ecology_motion_material(crown_low, pack, 0.34, 0.14 if _is_altered_phase() else 0.0))
	var cedar_is_combined := family == BiomeContentPack.VegetationFamily.CEDAR_FIR
	var primary_visual := _combine_tree_mesh(trunk, crown, 1.42, trunk_height * 0.43) if cedar_is_combined else crown
	var secondary_visual := _combine_tree_mesh(trunk, secondary_crown, 1.42, trunk_height * 0.43) if cedar_is_combined else secondary_crown
	var trunks := _new_multimesh(trunk, 0 if cedar_is_combined else count)
	var primary_crowns := _new_multimesh(primary_visual, count * crown_layers)
	var secondary_crowns := _new_multimesh(secondary_visual, count * crown_layers)
	var placed := 0
	var primary_placed := 0
	var secondary_placed := 0
	var variant_seed: int = absi(int(_chunk_seed(coordinate)))
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
		if not cedar_is_combined:
			var trunk_y := ground if trunk_has_base_origin else ground + trunk_height * 0.5 * size
			trunks.set_instance_transform(placed, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(size, size, size)), Vector3(point.x, trunk_y, point.y)))
			trunks.set_instance_color(placed, Color(0.18, 0.065, 0.025).lerp(Color(0.36, 0.16, 0.05), rng.randf()))
		# The ratio is deterministic per chunk, so streaming a chunk out and in never
		# changes its silhouette. Secondary forms are common enough to shape the view,
		# but primary forms still define the biome at a glance.
		var use_secondary: bool = (variant_seed + placed * 7) % 5 >= 3
		for layer in crown_layers:
			var crown_scale := size * (1.15 - float(layer) * 0.2)
			var offset := Vector3(0, size * (trunk_height * 0.57 + float(layer) * 1.2), 0)
			if cedar_is_combined:
				crown_scale = size
				offset = Vector3.ZERO
			if family != BiomeContentPack.VegetationFamily.CEDAR_FIR:
				offset += Vector3(cos(yaw + layer * PI), 0, sin(yaw + layer * PI)) * size * 0.65
			if family == BiomeContentPack.VegetationFamily.ANTLER_LARCH:
				offset += Vector3(cos(yaw + layer * 1.57), float(layer) * 0.3, sin(yaw + layer * 1.57)) * size * 1.15
			if family == BiomeContentPack.VegetationFamily.CONCORDANT_GROVE:
				offset.y += sin(float(layer) * 2.1) * size
			var crown_rotation := Vector3(0.0, yaw + layer * 0.3, 0.0)
			if family == BiomeContentPack.VegetationFamily.CONCORDANT_GROVE:
				crown_rotation.z = float(layer) * 0.52
			var crown_transform := Transform3D(Basis.from_euler(crown_rotation).scaled(Vector3(crown_scale, size, crown_scale)), Vector3(point.x, ground, point.y) + offset)
			var ordinary := Color(0.055, 0.24, 0.075).lerp(Color(0.4, 0.55, 0.12), rng.randf_range(0.0, 0.65))
			var altered_low := _phase_definition.canopy_low if _phase_definition != null else Color(0.15, 0.05, 0.32)
			var altered_high := _phase_definition.canopy_high if _phase_definition != null else Color(0.95, 0.12, 0.62)
			var altered := altered_low.lerp(altered_high, rng.randf_range(0.15, 0.8))
			var crown_color := altered if _is_altered_phase() else ordinary
			if use_secondary:
				secondary_crowns.set_instance_transform(secondary_placed, crown_transform)
				secondary_crowns.set_instance_color(secondary_placed, crown_color)
				secondary_placed += 1
			else:
				primary_crowns.set_instance_transform(primary_placed, crown_transform)
				primary_crowns.set_instance_color(primary_placed, crown_color)
				primary_placed += 1
		placed += 1
	trunks.instance_count = 0 if cedar_is_combined else placed
	primary_crowns.instance_count = primary_placed
	secondary_crowns.instance_count = secondary_placed
	_set_multimesh_chunk_bounds(trunks, coordinate)
	_set_multimesh_chunk_bounds(primary_crowns, coordinate)
	_set_multimesh_chunk_bounds(secondary_crowns, coordinate)
	_add_multimesh_instance(body, "VegetationTrunks_%d" % family, trunks)
	_add_multimesh_instance(body, "VegetationCrownsPrimary_%d" % family, primary_crowns)
	_add_multimesh_instance(body, "VegetationCrownsSecondary_%d" % family, secondary_crowns, false)


func _combine_tree_mesh(trunk: Mesh, crown: Mesh, crown_scale: float, crown_height: float) -> ArrayMesh:
	var combined := ArrayMesh.new()
	var trunk_surface := SurfaceTool.new()
	trunk_surface.append_from(trunk, 0, Transform3D.IDENTITY)
	trunk_surface.commit(combined)
	var crown_surface := SurfaceTool.new()
	var crown_transform := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * crown_scale), Vector3.UP * crown_height)
	crown_surface.append_from(crown, 0, crown_transform)
	crown_surface.commit(combined)
	return combined


func _add_rock_multimesh(body: Node3D, coordinate: Vector2i, rng: RandomNumberGenerator, count: int) -> void:
	var pack := _get_content_pack()
	var family := pack.geology_family if pack != null else BiomeContentPack.GeologyFamily.ROUNDED_GRANITE
	var mesh: Mesh
	var secondary_mesh: Mesh
	var primary_height := 1.35
	var secondary_height := 1.35
	match family:
		BiomeContentPack.GeologyFamily.ROUNDED_GRANITE:
			mesh = _cached_biome_mesh(&"granite_boulder", "create_granite_boulder")
			secondary_mesh = _cached_biome_mesh(&"granite_slab", "create_granite_slab")
			primary_height = 1.55
			secondary_height = 1.2
		BiomeContentPack.GeologyFamily.ROOT_NODULES:
			mesh = _cached_biome_mesh(&"root_nodule", "create_root_nodule")
			secondary_mesh = _cached_biome_mesh(&"root_bulb_cluster", "create_root_bulb_cluster")
			primary_height = 1.8
			secondary_height = 1.68
		BiomeContentPack.GeologyFamily.KARST_RIBS:
			mesh = _cached_biome_mesh(&"karst_rib", "create_karst_rib")
			secondary_mesh = _cached_biome_mesh(&"karst_stack", "create_karst_stack")
			primary_height = 3.5
			secondary_height = 2.66
		BiomeContentPack.GeologyFamily.ICE_CRYSTALS:
			mesh = _cached_biome_mesh(&"ice_geology", "create_ice_geology")
			secondary_mesh = _cached_biome_mesh(&"ice_arch", "create_ice_arch")
			primary_height = 3.4
			secondary_height = 3.2
		BiomeContentPack.GeologyFamily.FLOATING_STRATA:
			mesh = _cached_biome_mesh(&"floating_strata", "create_floating_strata")
			secondary_mesh = _cached_biome_mesh(&"floating_shard", "create_floating_shard")
			primary_height = 1.44
			secondary_height = 2.25
		BiomeContentPack.GeologyFamily.RED_SCREE:
			mesh = _cached_biome_mesh(&"red_scree", "create_red_scree")
			secondary_mesh = _cached_biome_mesh(&"red_monolith", "create_red_monolith")
			primary_height = 1.2
			secondary_height = 2.45
		BiomeContentPack.GeologyFamily.ASH_COLUMNS:
			mesh = _cached_biome_mesh(&"ash_column", "create_ash_column")
			secondary_mesh = _cached_biome_mesh(&"ash_cairn", "create_ash_cairn")
			primary_height = 3.1
			secondary_height = 1.26
		_:
			mesh = _cached_biome_mesh(&"wetland_shelf", "create_wetland_shelf")
			secondary_mesh = _cached_biome_mesh(&"wetland_stone", "create_wetland_stone")
			primary_height = 0.58
			secondary_height = 0.72
	var luminous := family == BiomeContentPack.GeologyFamily.ICE_CRYSTALS or family == BiomeContentPack.GeologyFamily.FLOATING_STRATA
	_set_mesh_material(mesh, _standard_material(pack.ground_high if pack != null else Color(0.26, 0.28, 0.24), luminous))
	_set_mesh_material(secondary_mesh, _standard_material(pack.ground_high if pack != null else Color(0.26, 0.28, 0.24), luminous))
	var primary_multimesh := _new_multimesh(mesh, count)
	var secondary_multimesh := _new_multimesh(secondary_mesh, count)
	var placed := 0
	var primary_placed := 0
	var secondary_placed := 0
	var variant_seed: int = absi(int(_chunk_seed(coordinate)))
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
		var use_secondary: bool = (variant_seed + placed * 11) % 7 >= 4
		var mesh_height := secondary_height if use_secondary else primary_height
		var instance_transform := Transform3D(basis, Vector3(point.x, ground + mesh_height * vertical_scale * 0.42, point.y))
		var ordinary := Color(0.19, 0.24, 0.2).lerp(Color(0.48, 0.42, 0.28), rng.randf())
		var altered_low := _phase_definition.stone_low if _phase_definition != null else Color(0.08, 0.32, 0.42)
		var altered_high := _phase_definition.stone_high if _phase_definition != null else Color(0.7, 0.16, 0.65)
		var altered := altered_low.lerp(altered_high, rng.randf())
		var instance_color := altered if _is_altered_phase() else ordinary
		if use_secondary:
			secondary_multimesh.set_instance_transform(secondary_placed, instance_transform)
			secondary_multimesh.set_instance_color(secondary_placed, instance_color)
			secondary_placed += 1
		else:
			primary_multimesh.set_instance_transform(primary_placed, instance_transform)
			primary_multimesh.set_instance_color(primary_placed, instance_color)
			primary_placed += 1
		placed += 1
	primary_multimesh.instance_count = primary_placed
	secondary_multimesh.instance_count = secondary_placed
	_set_multimesh_chunk_bounds(primary_multimesh, coordinate)
	_set_multimesh_chunk_bounds(secondary_multimesh, coordinate)
	_add_multimesh_instance(body, "GeologyPrimary_%d" % family, primary_multimesh)
	_add_multimesh_instance(body, "GeologySecondary_%d" % family, secondary_multimesh, false)


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
	_set_multimesh_chunk_bounds(multimesh, coordinate)
	# Hundreds of ankle-high plants do not contribute a readable silhouette, but
	# rendering them into every directional shadow cascade is expensive.
	_add_multimesh_instance(body, "Groundcover_%d" % ecology, multimesh, false)


func _add_zone_accent_cluster(body: Node3D, coordinate: Vector2i, rng: RandomNumberGenerator, pack: BiomeContentPack, zone: int) -> void:
	if pack == null or zone == LandscapeZone.SHELTER_EDGE:
		return
	var chunk_center := Vector2((float(coordinate.x) + 0.5) * chunk_size, (float(coordinate.y) + 0.5) * chunk_size)
	var route_x := _route_center_x(chunk_center.y)
	var frames_route := absf(chunk_center.x - route_x) <= chunk_size * 0.78
	# Route chunks always receive one readable side composition. Remote chunks use
	# sparse deterministic clusters, leaving large negative spaces between vistas.
	if not frames_route and absi(_chunk_seed(coordinate)) % 3 != 0:
		return
	var mesh: Mesh
	var scale_range := Vector2(0.55, 1.0)
	var height_offset := 0.02
	match pack.ecology_family:
		BiomeContentPack.EcologyFamily.ALTAI_TAIGA:
			mesh = _cached_biome_mesh(&"zone_young_cedar", &"create_conifer_crown_windformed")
			scale_range = Vector2(0.28, 0.58)
		BiomeContentPack.EcologyFamily.MYCELIAL_KARST:
			mesh = _cached_biome_mesh(&"zone_bell_caps", &"create_fungus_cap_bell")
			scale_range = Vector2(0.46, 0.88)
		BiomeContentPack.EcologyFamily.CRIMSON_STEPPE:
			mesh = _cached_biome_mesh(&"zone_antler_scrub", &"create_antler_crown_swept")
			scale_range = Vector2(0.34, 0.68)
		BiomeContentPack.EcologyFamily.GLACIAL_CIRQUE:
			mesh = _cached_biome_mesh(&"zone_ice_arch", &"create_ice_arch")
			scale_range = Vector2(0.34, 0.66)
		BiomeContentPack.EcologyFamily.ASHEN_TUNDRA:
			mesh = _cached_biome_mesh(&"zone_ash_cairn", &"create_ash_cairn")
			scale_range = Vector2(0.58, 1.08)
		BiomeContentPack.EcologyFamily.MIRROR_WETLAND:
			mesh = _cached_biome_mesh(&"zone_wetland_shelf", &"create_wetland_shelf")
			scale_range = Vector2(0.72, 1.28)
		BiomeContentPack.EcologyFamily.ROOT_CAVERN:
			mesh = _cached_biome_mesh(&"zone_root_bulb", &"create_root_bulb_cluster")
			scale_range = Vector2(0.46, 0.92)
		_:
			mesh = _cached_biome_mesh(&"zone_floating_shard", &"create_floating_shard")
			scale_range = Vector2(0.42, 0.78)
			height_offset = 0.85
	var material_color := pack.ground_high.lerp(pack.accent_color, 0.46)
	_set_mesh_material(mesh, _standard_material(material_color, pack.ecology_family in [BiomeContentPack.EcologyFamily.MYCELIAL_KARST, BiomeContentPack.EcologyFamily.HEART_PLATEAU]))
	var count := 5
	match zone:
		LandscapeZone.DENSE_FOREST:
			count = 7
		LandscapeZone.RIVER_VALLEY, LandscapeZone.BASIN:
			count = 6
		LandscapeZone.HIGHLAND:
			count = 4
		LandscapeZone.ALPINE, LandscapeZone.BOUNDARY:
			count = 3
	var multimesh := _new_multimesh(mesh, count)
	var side := -1.0 if absi(_chunk_seed(coordinate)) % 2 == 0 else 1.0
	var minimum_x := float(coordinate.x) * chunk_size + 2.0
	var maximum_x := float(coordinate.x + 1) * chunk_size - 2.0
	var minimum_z := float(coordinate.y) * chunk_size + 2.0
	var maximum_z := float(coordinate.y + 1) * chunk_size - 2.0
	var anchor := _random_chunk_point(coordinate, rng)
	if frames_route:
		var required_room := pack.route_width * 1.75 + 4.2
		var preferred_room := (maximum_x - route_x) if side > 0.0 else (route_x - minimum_x)
		var opposite_room := (route_x - minimum_x) if side > 0.0 else (maximum_x - route_x)
		if preferred_room < required_room and opposite_room > preferred_room:
			side *= -1.0
		anchor.x = clampf(route_x + side * (pack.route_width * 1.75 + 4.2), minimum_x, maximum_x)
		anchor.y = clampf(chunk_center.y + rng.randf_range(-chunk_size * 0.28, chunk_size * 0.28), minimum_z, maximum_z)
	var placed := 0
	for _attempt: int in count * 5:
		if placed >= count:
			break
		var angle := TAU * float(placed) / float(count) + rng.randf_range(-0.42, 0.42)
		var radius := rng.randf_range(0.8, 4.2) * (0.72 + float(placed % 3) * 0.18)
		var point := anchor + Vector2(cos(angle), sin(angle)) * radius
		point.x = clampf(point.x, minimum_x, maximum_x)
		point.y = clampf(point.y, minimum_z, maximum_z)
		# The cluster itself is the authored patch. Reapplying the scatter-noise gate
		# to every member dissolved most groups into isolated single props.
		if _is_reserved(point) or get_region_ratio(point) > 1.02:
			continue
		var scale_value := rng.randf_range(scale_range.x, scale_range.y)
		var basis := Basis.from_euler(Vector3(0.0, rng.randf_range(0.0, TAU), rng.randf_range(-0.12, 0.12))).scaled(Vector3(scale_value * rng.randf_range(0.82, 1.22), scale_value, scale_value))
		var ground := _height_at(point.x, point.y)
		multimesh.set_instance_transform(placed, Transform3D(basis, Vector3(point.x, ground + height_offset * scale_value, point.y)))
		multimesh.set_instance_color(placed, material_color.lerp(pack.accent_color, rng.randf_range(0.0, 0.28)))
		placed += 1
	if placed == 0 and not _is_reserved(anchor) and get_region_ratio(anchor) <= 1.02:
		var fallback_scale := (scale_range.x + scale_range.y) * 0.5
		var fallback_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * fallback_scale)
		multimesh.set_instance_transform(0, Transform3D(fallback_basis, Vector3(anchor.x, _height_at(anchor.x, anchor.y) + height_offset * fallback_scale, anchor.y)))
		multimesh.set_instance_color(0, material_color)
		placed = 1
	multimesh.instance_count = placed
	_set_multimesh_chunk_bounds(multimesh, coordinate)
	_add_multimesh_instance(body, "ZoneAccent_%d_%d" % [pack.ecology_family, zone], multimesh, false)


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
	elif poi_family == &"memory_ring":
		_add_memory_ring_core(root, center, rng, pack)
	elif poi_family == &"reflection_pool":
		_add_reflection_pool_core(root, center, rng, pack)
	elif poi_family == &"root_mouth":
		_add_root_mouth_core(root, center, rng, pack)
	elif poi_family == &"brothers_heart":
		_add_brothers_heart_core(root, center, rng, pack)
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


func _add_memory_ring_core(root: Node3D, center: Vector2, rng: RandomNumberGenerator, pack: BiomeContentPack) -> void:
	var ground := _height_at(center.x, center.y)
	var stem_material := _standard_material(pack.ground_high.darkened(0.55))
	var cap_material := _standard_material(pack.accent_color.darkened(0.18), true)
	var stem := MeshInstance3D.new()
	stem.name = "RememberingStem"
	stem.mesh = BIOME_MESH_LIBRARY.create_fungus_stem()
	stem.material_override = stem_material
	stem.scale = Vector3(1.3, 1.55, 1.3)
	stem.position = Vector3(center.x, ground, center.y)
	stem.rotation.y = rng.randf_range(0.0, TAU)
	root.add_child(stem)
	var cap := MeshInstance3D.new()
	cap.name = "ListeningBellCap"
	cap.mesh = BIOME_MESH_LIBRARY.create_fungus_cap_bell()
	cap.material_override = cap_material
	cap.scale = Vector3(2.15, 1.8, 2.15)
	cap.position = Vector3(center.x, ground + 7.6, center.y)
	cap.rotation = Vector3(PI, rng.randf_range(0.0, TAU), 0.0)
	root.add_child(cap)
	for index: int in 9:
		var angle := TAU * float(index) / 9.0
		var radius := 2.2 + 0.42 * float(index % 3)
		var point := center + Vector2(cos(angle), sin(angle)) * radius
		var witness := MeshInstance3D.new()
		witness.name = "MemoryTooth_%02d" % index
		witness.mesh = BIOME_MESH_LIBRARY.create_karst_rib() if index % 2 == 0 else BIOME_MESH_LIBRARY.create_karst_stack()
		witness.material_override = _standard_material(pack.ground_high.darkened(0.34 + 0.06 * float(index % 2)))
		witness.scale = Vector3.ONE * rng.randf_range(0.46, 0.8)
		witness.position = Vector3(point.x, _height_at(point.x, point.y), point.y)
		witness.rotation = Vector3(rng.randf_range(-0.12, 0.12), -angle, rng.randf_range(-0.14, 0.14))
		root.add_child(witness)


func _add_reflection_pool_core(root: Node3D, center: Vector2, rng: RandomNumberGenerator, pack: BiomeContentPack) -> void:
	var ground := _height_at(center.x, center.y)
	var pool := MeshInstance3D.new()
	pool.name = "StillWaterEye"
	var pool_mesh := CylinderMesh.new()
	pool_mesh.top_radius = 3.5
	pool_mesh.bottom_radius = 3.85
	pool_mesh.height = 0.055
	pool_mesh.radial_segments = 18
	var water_material := _standard_material(pack.accent_color.darkened(0.28), true)
	water_material.metallic = 0.82
	water_material.roughness = 0.08
	pool_mesh.material = water_material
	pool.mesh = pool_mesh
	pool.position = Vector3(center.x, ground + 0.08, center.y)
	root.add_child(pool)
	# Two unequal marker families sell the idea of a reflection that has begun to
	# disagree with the real bank instead of merely adding another water disc.
	for side: int in [-1, 1]:
		for index: int in 4:
			var marker := MeshInstance3D.new()
			marker.name = "ReflectionWitness_%d_%02d" % [side, index]
			marker.mesh = BIOME_MESH_LIBRARY.create_reed_fan() if side < 0 else BIOME_MESH_LIBRARY.create_wetland_shelf()
			marker.material_override = _standard_material(pack.ground_high.darkened(0.28 if side < 0 else 0.46), side > 0)
			var offset := Vector2(float(side) * (4.1 + index * 0.52), float(index - 2) * 1.35)
			var point := center + offset
			marker.position = Vector3(point.x, _height_at(point.x, point.y), point.y)
			marker.scale = Vector3.ONE * (1.25 + float(index % 2) * 0.35)
			marker.rotation.y = rng.randf_range(-0.25, 0.25) + (PI if side > 0 else 0.0)
			root.add_child(marker)


func _add_root_mouth_core(root: Node3D, center: Vector2, rng: RandomNumberGenerator, pack: BiomeContentPack) -> void:
	var ground := _height_at(center.x, center.y)
	var root_material := _standard_material(pack.ground_high.darkened(0.42))
	var void_material := _standard_material(Color(0.008, 0.002, 0.012), true)
	for index: int in 4:
		var arch := MeshInstance3D.new()
		arch.name = "RootThroat_%02d" % index
		arch.mesh = BIOME_MESH_LIBRARY.create_root_loop() if index % 2 == 0 else BIOME_MESH_LIBRARY.create_root_spire()
		arch.material_override = root_material
		arch.scale = Vector3.ONE * (2.35 - float(index) * 0.26)
		arch.position = Vector3(center.x, ground + 3.1, center.y + float(index) * 1.18)
		arch.rotation = Vector3(0.0, rng.randf_range(-0.1, 0.1), 0.0)
		root.add_child(arch)
	var darkness := MeshInstance3D.new()
	darkness.name = "RootMouthDarkness"
	var darkness_mesh := SphereMesh.new()
	darkness_mesh.radius = 2.15
	darkness_mesh.height = 4.5
	darkness_mesh.radial_segments = 10
	darkness_mesh.rings = 6
	darkness_mesh.material = void_material
	darkness.mesh = darkness_mesh
	darkness.scale = Vector3(0.75, 1.0, 0.26)
	darkness.position = Vector3(center.x, ground + 2.5, center.y + 3.55)
	root.add_child(darkness)
	var ilya_echo := ILYA_ROOT_ECHO.instantiate() as AuthoredNPCEncounter
	ilya_echo.name = "IlyaRootEcho"
	ilya_echo.required_clue_id = &""
	ilya_echo.position = Vector3(center.x + 3.45, ground + 0.04, center.y - 2.75)
	ilya_echo.rotation.y = -0.56
	ilya_echo.encounter_completed.connect(func(clue_id: StringName, title: String, text: String) -> void:
		authored_encounter_completed.emit(clue_id, title, text)
	)
	root.add_child(ilya_echo)


func _add_brothers_heart_core(root: Node3D, center: Vector2, rng: RandomNumberGenerator, pack: BiomeContentPack) -> void:
	var ground := _height_at(center.x, center.y)
	var ring_material := _standard_material(pack.accent_color, true)
	var strata_material := _standard_material(pack.ground_high.darkened(0.28), true)
	for side: int in [-1, 1]:
		var heart := MeshInstance3D.new()
		heart.name = "BrotherArc_%d" % side
		heart.mesh = BIOME_MESH_LIBRARY.create_heart_branch()
		heart.material_override = ring_material
		heart.scale = Vector3.ONE * 2.1
		heart.position = Vector3(center.x + float(side) * 1.05, ground + 0.2, center.y)
		heart.rotation = Vector3(0.0, float(side) * 0.22, float(side) * -0.12)
		root.add_child(heart)
	for index: int in 5:
		var angle := TAU * float(index) / 5.0 + rng.randf_range(-0.14, 0.14)
		var point := center + Vector2(cos(angle), sin(angle)) * rng.randf_range(3.2, 5.0)
		var stratum := MeshInstance3D.new()
		stratum.name = "ConcordanceStratum_%02d" % index
		stratum.mesh = BIOME_MESH_LIBRARY.create_floating_shard() if index % 2 == 0 else BIOME_MESH_LIBRARY.create_floating_strata()
		stratum.material_override = strata_material
		stratum.scale = Vector3.ONE * rng.randf_range(0.72, 1.18)
		stratum.position = Vector3(point.x, _height_at(point.x, point.y) + 2.1 + float(index % 3) * 1.25, point.y)
		stratum.rotation = Vector3(rng.randf_range(-0.22, 0.22), angle, rng.randf_range(-0.18, 0.18))
		root.add_child(stratum)


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
	var region_ratio := get_region_ratio(point)
	if region_ratio > 1.035:
		return false
	# Offset noise fields prevent trees, stone and groundcover from becoming one
	# uniform procedural carpet. Each layer forms patches and leaves authored
	# negative space around the route and major compositions.
	var ecology_offset := float(pack.ecology_family) * 173.0
	var broad := _noise.get_noise_2d(point.x * 0.72 + ecology_offset, point.y * 0.72 - ecology_offset)
	var detail := _detail_noise.get_noise_2d(point.x * 0.38 - ecology_offset, point.y * 0.38 + ecology_offset)
	match layer:
		0: # Vegetation forms groves and deliberate clearings.
			var threshold := lerpf(0.08, -0.24, clampf(pack.vegetation_density / 1.6, 0.0, 1.0))
			if region_ratio > pack.boundary_inner_ratio:
				threshold += 0.34
			return broad + detail * 0.28 > threshold
		1: # Geology traces different bands instead of shadowing the trees.
			if region_ratio > pack.boundary_inner_ratio:
				return broad + detail * 0.35 > -0.42
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
	var pack := _get_content_pack()
	var clear_route_width := (pack.route_width if pack != null else 5.5) * 0.44
	if _distance_to_expedition_route(point) < clear_route_width:
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
	var pack := _get_content_pack()
	var wander_scale := pack.route_wander_scale if pack != null else 1.0
	var wandering := (sin(z * 0.018 + seed_phase) * 17.0 + sin(z * 0.0065 - seed_phase * 0.37 + phase_offset) * 9.0) * wander_scale
	if pack != null:
		match pack.ecology_family:
			BiomeContentPack.EcologyFamily.MYCELIAL_KARST:
				wandering += sin(z * 0.052 + seed_phase * 1.7) * 5.5
			BiomeContentPack.EcologyFamily.MIRROR_WETLAND:
				wandering += sin(z * 0.011 - seed_phase) * 7.0
			BiomeContentPack.EcologyFamily.ROOT_CAVERN:
				wandering += sin(z * 0.044 + phase_offset) * 7.5
	# Preserve the authored first departure from camp, then let the route become seed-specific.
	return wandering * smoothstep(42.0, 105.0, z)


func _distance_to_expedition_route(point: Vector2) -> float:
	return absf(point.x - _route_center_x(point.y))


func _should_place_landmark(coordinate: Vector2i, pack: BiomeContentPack) -> bool:
	var period := pack.landmark_period if pack != null else 7
	if posmod(coordinate.y - 2, period) != 0:
		return false
	var intended := _landmark_center_for_row(coordinate.y, pack)
	if get_region_ratio(intended) >= (pack.boundary_inner_ratio - 0.04 if pack != null else 0.74):
		return false
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
	if get_region_ratio(intended) >= pack.boundary_inner_ratio - 0.02:
		return false
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
		_retire_chunk(_chunks[coordinate])
	_chunks.clear()
	_pending = coordinates


func _retire_chunk(chunk: StaticBody3D) -> void:
	if not is_instance_valid(chunk):
		return
	# Detach immediately so old collision and rendering cannot overlap a freshly
	# generated replacement until queue_free is processed at the end of the frame.
	if chunk.get_parent() == self:
		remove_child(chunk)
	chunk.queue_free()


func _rebuild_world_geometry() -> void:
	var focus := _target.global_position if is_instance_valid(_target) else Vector3(0, 0, 15)
	_rebuild_loaded_chunks()
	_refresh_chunks(focus, true)


func _rebuild_loaded_decor() -> void:
	for coordinate: Vector2i in _chunks:
		var body := _chunks[coordinate]
		for child: Node in body.get_children():
			if child.name != "Terrain" and child.name != "Collision":
				body.remove_child(child)
				child.queue_free()
		if int(body.get_meta(&"terrain_detail_tier", 0)) >= 1:
			_build_chunk_decor(body, coordinate)


func _new_multimesh(mesh: Mesh, count: int) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	return multimesh


func _set_multimesh_chunk_bounds(multimesh: MultiMesh, coordinate: Vector2i) -> void:
	# MultiMesh is culled as one object. Tight per-chunk bounds let Godot reject the
	# entire grove behind/outside the camera instead of treating its AABB as unknown.
	var origin := Vector3(float(coordinate.x) * chunk_size - 3.0, -72.0, float(coordinate.y) * chunk_size - 3.0)
	multimesh.custom_aabb = AABB(origin, Vector3(chunk_size + 6.0, 156.0, chunk_size + 6.0))


func _add_multimesh_instance(parent: Node3D, node_name: String, multimesh: MultiMesh, casts_shadow: bool = true) -> void:
	if multimesh.instance_count == 0:
		return
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = chunk_size * float(active_radius + 1)
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(instance)


func _rebuild_presentation_layers() -> void:
	if is_instance_valid(_horizon_root):
		if _horizon_root.get_parent() == self:
			remove_child(_horizon_root)
		_horizon_root.queue_free()
	if is_instance_valid(_atmosphere):
		if _atmosphere.get_parent() == self:
			remove_child(_atmosphere)
		_atmosphere.queue_free()
	_horizon_root = Node3D.new()
	_horizon_root.name = "BiomeHorizon"
	add_child(_horizon_root)
	var pack := _get_content_pack()
	# The horizon is an HLOD representation of the authored finite border. It must
	# stay at the map centre: a camera-centred ridge makes every mountain follow
	# the player and destroys the sense of a coherent place.
	_horizon_root.position = Vector3(0.0, 0.0, (pack.region_south + pack.region_length * 0.5) if pack != null else 340.0)
	var ecology := pack.ecology_family if pack != null else BiomeContentPack.EcologyFamily.ALTAI_TAIGA
	if not is_instance_valid(_biome_ambience):
		_biome_ambience = BIOME_AMBIENCE.new() as AudioStreamPlayer
		_biome_ambience.name = "BiomeRecordedAmbience"
		add_child(_biome_ambience)
	_biome_ambience.call("configure", ecology, base_seed + _run_seed)
	_biome_ambience.call("set_expedition_active", is_instance_valid(_target) and _target.global_position.z >= MIN_EXPEDITION_Z)
	var rng := RandomNumberGenerator.new()
	rng.seed = base_seed * 97 + _run_seed * 53 + ecology * 101
	_build_layered_ridge_horizon(rng, pack)
	match ecology:
		BiomeContentPack.EcologyFamily.ALTAI_TAIGA:
			# The finite terrain now owns the forest silhouette. The old camera-centred
			# cedar ring followed the player forever and exposed unpaired pole shapes.
			pass
		BiomeContentPack.EcologyFamily.MYCELIAL_KARST:
			_build_fungal_horizon(rng, pack)
		_:
			_build_signature_horizon(rng, pack)
	_build_celestial_anchor(pack)
	_build_biome_atmosphere(pack)


func _build_layered_ridge_horizon(rng: RandomNumberGenerator, pack: BiomeContentPack) -> void:
	var low := pack.ground_low if pack != null else Color(0.055, 0.15, 0.065)
	var high := pack.ground_high if pack != null else Color(0.28, 0.27, 0.12)
	var ecology := pack.ecology_family if pack != null else BiomeContentPack.EcologyFamily.ALTAI_TAIGA
	var relief_multiplier := 1.0
	if ecology == BiomeContentPack.EcologyFamily.GLACIAL_CIRQUE:
		relief_multiplier = 1.38
	elif ecology in [BiomeContentPack.EcologyFamily.MIRROR_WETLAND, BiomeContentPack.EcologyFamily.ASHEN_TUNDRA]:
		relief_multiplier = 0.62
	elif ecology == BiomeContentPack.EcologyFamily.ROOT_CAVERN:
		relief_multiplier = 0.82
	for layer: int in 3:
		var boundary_scale := 1.025 + float(layer) * 0.09
		var authored_boundary_height := pack.boundary_height if pack != null else 48.0
		var base_height := authored_boundary_height * (0.24 - float(layer) * 0.025) * relief_multiplier
		var amplitude := (7.0 - float(layer) * 1.1) * relief_multiplier
		var peak_height := authored_boundary_height * (0.72 - float(layer) * 0.1) * relief_multiplier
		var phase_a := rng.randf_range(0.0, TAU)
		var phase_b := rng.randf_range(0.0, TAU)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var material := _standard_material(low.lerp(high, 0.15 + float(layer) * 0.16).darkened(0.32 + float(layer) * 0.1))
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		surface.set_material(material)
		var segments := 96
		for index: int in segments:
			var angle_a := TAU * float(index) / float(segments)
			var angle_b := TAU * float(index + 1) / float(segments)
			var point_a := _horizon_boundary_point(angle_a, boundary_scale, pack)
			var point_b := _horizon_boundary_point(angle_b, boundary_scale, pack)
			var radial_a := Vector2(point_a.x, point_a.z).normalized()
			var radial_b := Vector2(point_b.x, point_b.z).normalized()
			point_a += Vector3(radial_a.x, 0.0, radial_a.y) * (sin(angle_a * 5.0 + phase_a) * 5.2 + sin(angle_a * 11.0 + phase_b) * 1.8)
			point_b += Vector3(radial_b.x, 0.0, radial_b.y) * (sin(angle_b * 5.0 + phase_a) * 5.2 + sin(angle_b * 11.0 + phase_b) * 1.8)
			var peak_a := pow(absf(sin(angle_a * (13.0 + float(layer) * 2.0) + phase_b)), 2.5) * peak_height
			var peak_b := pow(absf(sin(angle_b * (13.0 + float(layer) * 2.0) + phase_b)), 2.5) * peak_height
			var top_a := base_height + peak_a + sin(angle_a * 3.0 + phase_a) * amplitude + sin(angle_a * 8.0 + phase_b) * amplitude * 0.34
			var top_b := base_height + peak_b + sin(angle_b * 3.0 + phase_a) * amplitude + sin(angle_b * 8.0 + phase_b) * amplitude * 0.34
			var bottom_a := Vector3(point_a.x, -38.0, point_a.z)
			var bottom_b := Vector3(point_b.x, -38.0, point_b.z)
			var ridge_a := Vector3(point_a.x, top_a, point_a.z)
			var ridge_b := Vector3(point_b.x, top_b, point_b.z)
			surface.add_vertex(bottom_a)
			surface.add_vertex(bottom_b)
			surface.add_vertex(ridge_a)
			surface.add_vertex(bottom_b)
			surface.add_vertex(ridge_b)
			surface.add_vertex(ridge_a)
		surface.generate_normals()
		var ridge := MeshInstance3D.new()
		ridge.name = "DistantRidgeLayer_%02d" % layer
		ridge.mesh = surface.commit()
		ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_horizon_root.add_child(ridge)


func _horizon_boundary_point(angle: float, scale_factor: float, pack: BiomeContentPack) -> Vector3:
	var half_width := pack.region_half_width if pack != null else 410.0
	var half_length := (pack.region_length * 0.5) if pack != null else 460.0
	# Same rounded-superellipse family used by the playable region, reduced to a
	# single cheap ring for distant landscape rendering.
	var exponent := 2.0 / 2.4
	var cosine := cos(angle)
	var sine := sin(angle)
	return Vector3(
		sign(cosine) * pow(absf(cosine), exponent) * half_width * scale_factor,
		0.0,
		sign(sine) * pow(absf(sine), exponent) * half_length * scale_factor
	)


func _build_taiga_horizon_crown(rng: RandomNumberGenerator, pack: BiomeContentPack) -> void:
	var material := _standard_material(pack.ground_low.darkened(0.48) if pack != null else Color(0.018, 0.065, 0.028))
	var trunk_mesh := BIOME_MESH_LIBRARY.create_taiga_trunk()
	var crown_mesh := BIOME_MESH_LIBRARY.create_conifer_crown_windformed()
	_set_mesh_material(trunk_mesh, material)
	_set_mesh_material(crown_mesh, material)
	var trunks := _new_multimesh(trunk_mesh, 28)
	var crowns := _new_multimesh(crown_mesh, 28)
	for index: int in 28:
		var angle := TAU * float(index) / 28.0 + rng.randf_range(-0.07, 0.07)
		var radius := rng.randf_range(67.0, 76.0)
		var scale := rng.randf_range(2.0, 3.7)
		var position := Vector3(cos(angle) * radius, -1.5, sin(angle) * radius)
		var trunk_basis := Basis(Vector3.UP, -angle).scaled(Vector3.ONE * scale)
		trunks.set_instance_transform(index, Transform3D(trunk_basis, position))
		var crown_scale := scale * rng.randf_range(0.88, 1.14)
		var crown_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * crown_scale)
		crowns.set_instance_transform(index, Transform3D(crown_basis, position + Vector3.UP * 5.1 * scale))
	# Separate trunk/crown MultiMeshes need the same explicit spatial envelope.
	# Without it, Godot could keep the trunks while culling their crowns, producing
	# the forest of bare poles visible in earlier builds.
	var horizon_bounds := AABB(Vector3(-84.0, -5.0, -84.0), Vector3(168.0, 32.0, 168.0))
	trunks.custom_aabb = horizon_bounds
	crowns.custom_aabb = horizon_bounds
	_add_multimesh_instance(_horizon_root, "DistantCedarTrunks", trunks, false)
	_add_multimesh_instance(_horizon_root, "DistantCedarCrowns", crowns, false)


func _build_celestial_anchor(pack: BiomeContentPack) -> void:
	if pack == null:
		return
	var anchor := MeshInstance3D.new()
	anchor.name = "BiomeCelestialAnchor"
	var sphere := SphereMesh.new()
	var scale := 7.5
	if pack.ecology_family == BiomeContentPack.EcologyFamily.HEART_PLATEAU:
		scale = 13.0
	elif pack.ecology_family == BiomeContentPack.EcologyFamily.ROOT_CAVERN:
		scale = 9.5
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	var color := pack.accent_color.lightened(0.18)
	var material := _standard_material(color, true)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_energy_multiplier = 2.8
	sphere.material = material
	anchor.mesh = sphere
	anchor.scale = Vector3.ONE * scale
	anchor.position = Vector3(-pack.region_half_width * 0.58, 54.0, -pack.region_length * 0.38)
	_horizon_root.add_child(anchor)


func _build_fungal_horizon(rng: RandomNumberGenerator, pack: BiomeContentPack) -> void:
	var stem_mesh := BIOME_MESH_LIBRARY.create_fungus_stem()
	var cap_mesh := BIOME_MESH_LIBRARY.create_fungus_cap()
	_set_mesh_material(stem_mesh, _standard_material(Color(0.16, 0.045, 0.2)))
	_set_mesh_material(cap_mesh, _standard_material(pack.accent_color.darkened(0.42), true))
	for index in 13:
		var angle := TAU * float(index) / 13.0 + rng.randf_range(-0.12, 0.12)
		var scale := rng.randf_range(2.8, 5.4)
		var boundary_point := _horizon_boundary_point(angle, rng.randf_range(1.08, 1.14), pack)
		var stem := MeshInstance3D.new()
		stem.name = "DistantFungalStem_%02d" % index
		stem.mesh = stem_mesh
		stem.scale = Vector3(scale, scale, scale)
		stem.position = boundary_point
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
			scale_low = 1.25
			scale_high = 2.35
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
			scale_low = 3.5
			scale_high = 6.2
			base_y = 7.0
		BiomeContentPack.EcologyFamily.ROOT_CAVERN:
			mesh = BIOME_MESH_LIBRARY.create_root_loop()
			scale_low = 4.0
			scale_high = 6.8
			base_y = 10.0
		BiomeContentPack.EcologyFamily.HEART_PLATEAU:
			mesh = BIOME_MESH_LIBRARY.create_heart_loop()
			count = 11
			scale_low = 3.0
			scale_high = 5.2
			base_y = 9.0
		_:
			mesh = BIOME_MESH_LIBRARY.create_floating_strata()
			count = 14
			scale_low = 3.5
			scale_high = 6.2
			base_y = 10.0
	var silhouette_color := pack.accent_color.darkened(0.48)
	if pack.ecology_family == BiomeContentPack.EcologyFamily.GLACIAL_CIRQUE:
		silhouette_color = pack.accent_color.darkened(0.16)
	_set_mesh_material(mesh, _standard_material(silhouette_color, pack.ecology_family != BiomeContentPack.EcologyFamily.ASHEN_TUNDRA))
	for index in count:
		var silhouette := MeshInstance3D.new()
		silhouette.name = "SignatureHorizon_%02d" % index
		silhouette.mesh = mesh
		var angle := TAU * float(index) / float(count) + rng.randf_range(-0.1, 0.1)
		var scale := rng.randf_range(scale_low, scale_high)
		silhouette.scale = Vector3(scale * rng.randf_range(0.8, 1.25), scale, scale * rng.randf_range(0.75, 1.2))
		silhouette.position = _horizon_boundary_point(angle, rng.randf_range(1.08, 1.14), pack) + Vector3.UP * (base_y + rng.randf_range(-2.0, 3.0))
		silhouette.rotation.y = rng.randf_range(0.0, TAU)
		silhouette.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
uniform float weather_wetness : hint_range(0.0, 1.0) = 0.0;
uniform float weather_snow : hint_range(0.0, 1.0) = 0.0;
uniform vec3 phase_low : source_color = vec3(0.025, 0.16, 0.32);
uniform vec3 phase_high : source_color = vec3(0.82, 0.025, 0.7);
uniform vec3 surface_low : source_color = vec3(0.105, 0.255, 0.135);
uniform vec3 surface_high : source_color = vec3(0.46, 0.4, 0.21);
uniform vec3 surface_accent : source_color = vec3(0.53, 0.69, 0.24);
varying float pulse;
varying vec3 terrain_position;
varying float terrain_slope;
varying float terrain_macro;
varying float terrain_detail;
varying float terrain_cloud_shadow;
float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}
float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	return mix(
		mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), local.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), local.x),
		local.y
	);
}
global uniform vec3 trip_wind_vector;
global uniform float trip_wind_strength;
global uniform float trip_cloud_coverage;
global uniform float trip_cloud_storm;
global uniform float trip_night;
void vertex() {
	terrain_position = VERTEX;
	terrain_slope = 1.0 - abs(NORMAL.y);
	terrain_macro = value_noise(VERTEX.xz * 0.075);
	terrain_detail = value_noise(VERTEX.xz * 0.46 + vec2(17.2, -8.4));
	vec2 wind_direction = normalize(trip_wind_vector.xz + vec2(0.001));
	vec2 cloud_uv = VERTEX.xz * 0.018 + wind_direction * TIME * mix(0.008, 0.035, trip_wind_strength);
	float cloud_field = value_noise(cloud_uv) * 0.68 + value_noise(cloud_uv * 2.07 + 13.7) * 0.32;
	float cloud_threshold = mix(0.78, 0.38, trip_cloud_coverage);
	terrain_cloud_shadow = smoothstep(cloud_threshold, cloud_threshold + 0.2, cloud_field);
	float wave_a = sin(VERTEX.x * 0.075 + TIME * 0.65);
	float wave_b = cos(VERTEX.z * 0.061 - TIME * 0.48);
	pulse = wave_a * wave_b;
	VERTEX.y += pulse * 0.32 * metamorphosis;
}
void fragment() {
	vec3 mundane = COLOR.rgb;
	float broad = 0.5 + 0.5 * sin((terrain_position.x + terrain_position.z) * 0.055 + pulse * 1.4);
	float macro_cells = terrain_macro;
	float cells = terrain_detail;
	float micro_detail = sin(dot(terrain_position.xz, vec2(0.82, 0.37))) * sin(dot(terrain_position.xz, vec2(-0.31, 1.17)));
	float height_band = 0.5 + 0.5 * sin(terrain_position.y * 0.47 + macro_cells * 2.8);
	float height_mask = smoothstep(-1.5, 22.0, terrain_position.y);
	float grain = mix(0.86, 1.14, cells) * mix(0.9, 1.1, macro_cells);
	float slope_mask = smoothstep(0.1, 0.46, terrain_slope);
	float organic_mask = smoothstep(0.46, 0.76, macro_cells) * (1.0 - slope_mask) * (1.0 - height_mask * 0.62);
	float basin_mask = (1.0 - smoothstep(0.0, 4.5, terrain_position.y)) * smoothstep(0.38, 0.72, cells);
	vec3 soil_palette = mix(surface_low, surface_high, clamp(height_mask * 0.76 + macro_cells * 0.24, 0.0, 1.0));
	vec3 organic_palette = mix(surface_low, surface_accent, 0.2) * mix(0.78, 1.02, cells);
	vec3 geology_palette = mix(phase_low, phase_high, clamp(height_mask * 0.58 + cells * 0.3, 0.0, 1.0));
	vec3 authored_surface = mix(mundane, soil_palette, 0.34);
	authored_surface = mix(authored_surface, organic_palette, organic_mask * 0.58);
	authored_surface = mix(authored_surface, surface_low * vec3(0.52, 0.62, 0.58), basin_mask * 0.54);
	authored_surface = mix(authored_surface, geology_palette, slope_mask * 0.76);
	float altered_trace = smoothstep(0.57, 0.83, broad * 0.44 + height_band * 0.28 + cells * 0.28);
	vec3 altered_palette = mix(phase_low, phase_high, broad * 0.34 + height_band * 0.38 + cells * 0.28);
	vec3 altered = mix(authored_surface, altered_palette, 0.12 + altered_trace * 0.2);
	vec3 ground = mix(authored_surface, altered, metamorphosis);
	ground *= grain;
	ground *= mix(0.92, 1.08, micro_detail * 0.5 + 0.5);
	// Steep faces keep their geology colour instead of collapsing to black. The
	// directional sun and SSAO still describe the slope; this is only a restrained
	// bounced-light floor for readable first-person navigation.
	ground = mix(ground, geology_palette * 0.82 + ground * 0.18, slope_mask * 0.24);
	ground *= mix(0.82, 1.08, height_band * (1.0 - slope_mask * 0.45));
	// Very dark authored palettes still need a readable navigation floor. Lift only
	// the missing luminance with the biome's own highland tint, preserving hue and
	// leaving true night substantially darker than daytime.
	float ground_luma = dot(ground, vec3(0.2126, 0.7152, 0.0722));
	float readability_floor = mix(0.085, 0.038, trip_night);
	ground += mix(surface_high, vec3(1.0), 0.62) * max(readability_floor - ground_luma, 0.0) * 0.92;
	float cloud_shadow = terrain_cloud_shadow;
	ground *= mix(1.0, mix(0.82, 0.7, trip_cloud_storm), cloud_shadow);
	float wet_mask = weather_wetness * mix(0.62, 1.0, cells) * (1.0 - slope_mask * 0.72);
	float snow_mask = weather_snow * smoothstep(0.34, 0.82, macro_cells + (1.0 - slope_mask) * 0.46);
	vec3 weathered_ground = mix(ground, ground * vec3(0.5, 0.58, 0.54), wet_mask * 0.7);
	ALBEDO = mix(weathered_ground, vec3(0.68, 0.79, 0.84) * mix(0.82, 1.08, cells), snow_mask * 0.88);
	ROUGHNESS = clamp(mix(0.96, 0.78, metamorphosis) - cells * 0.07 + slope_mask * 0.08 - wet_mask * 0.54, 0.22, 1.0);
	SPECULAR = mix(0.22, 0.68, wet_mask);
	AO = mix(0.94, 0.78, slope_mask * 0.72 + cloud_shadow * 0.12);
	// Only the consciousness pulse emits. The former constant ground emission
	// cancelled contact shadows and was the main source of the flat colour wash.
	vec3 indirect_fill = ground * mix(0.13, 0.17, trip_night) * (1.0 - cloud_shadow * 0.22);
	EMISSION = indirect_fill + altered_palette * metamorphosis * altered_trace * (0.018 + max(pulse, 0.0) * 0.065) * (1.0 - slope_mask * 0.72);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"metamorphosis", _phase_amount)
	material.set_shader_parameter(&"weather_wetness", 0.0)
	material.set_shader_parameter(&"weather_snow", 0.0)
	return material


func _sync_terrain_surface_palette(definition: WorldPhaseDefinition) -> void:
	if _terrain_material == null or definition == null:
		return
	var pack := definition.content_pack
	if pack == null:
		return
	_terrain_material.set_shader_parameter(&"surface_low", pack.ground_low)
	_terrain_material.set_shader_parameter(&"surface_high", pack.ground_high)
	_terrain_material.set_shader_parameter(&"surface_accent", pack.accent_color)


func set_weather_wetness(value: float) -> void:
	if _terrain_material != null:
		_terrain_material.set_shader_parameter(&"weather_wetness", clampf(value, 0.0, 1.0))


func set_weather_state(state: int, _title: String, intensity: float) -> void:
	if _terrain_material == null:
		return
	var local_snow := state == 4 # WeatherOrchestrator.State.SNOW without a cyclic script dependency.
	if local_snow and is_instance_valid(_target):
		local_snow = bool(get_environment_context(_target.global_position).get("can_snow", false))
	_terrain_material.set_shader_parameter(&"weather_snow", clampf(intensity, 0.0, 1.0) if local_snow else 0.0)


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
