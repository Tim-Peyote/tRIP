extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _validate_landscape_rules()
	var first := _create_scatter()
	var second := _create_scatter()
	first.set_run_seed(77123)
	second.set_run_seed(77123)
	await get_tree().process_frame
	var first_signature := first.get_generation_signature()
	var second_signature := second.get_generation_signature()
	_expect(first_signature == second_signature, "Equal world seeds did not reproduce biome dressing.")
	second.set_run_seed(99117)
	await get_tree().process_frame
	var changed_signature := second.get_generation_signature()
	_expect(first_signature != changed_signature, "Different world seeds did not change biome dressing.")
	first.free()
	second.free()
	_finish()


func _validate_landscape_rules() -> void:
	var terrain := ExpeditionTerrain.new()
	add_child(terrain)
	await get_tree().process_frame
	var clearing_height := terrain.get_height_at_global(Vector3(0, 0, 15))
	var trail_height := terrain.get_height_at_global(Vector3(0, 0, 35))
	var camp_height := terrain.get_height_at_global(Vector3(31.5, 0, 20.5))
	var ramp_height := terrain.get_height_at_global(Vector3(25, 0, 18.5))
	_expect(absf(clearing_height) < 0.08, "The shelter clearing is not authored as a stable landing area.")
	_expect(trail_height > -0.1 and trail_height < 0.35, "The expedition trail left its authored height corridor.")
	_expect(camp_height > 1.45, "The deep-grove camp landmark lost its natural elevation.")
	_expect(ramp_height > clearing_height and ramp_height < camp_height, "The camp approach is not a continuous slope.")
	_expect(terrain.get_loaded_chunk_count() >= 1, "Streaming terrain did not create its center chunk.")
	_expect(terrain.get_collision_chunk_count() == int(pow(float(terrain.collision_radius * 2 + 1), 2.0)), "The complete near collision neighbourhood was not built synchronously.")
	var origin_mesh := terrain.call("_build_chunk_mesh", Vector2i.ZERO, 25, true) as ArrayMesh
	var minimum_generated_z := INF
	for face_vertex: Vector3 in origin_mesh.get_faces():
		minimum_generated_z = minf(minimum_generated_z, face_vertex.z)
	_expect(minimum_generated_z < 0.1, "Streaming terrain still has an artificial southern world edge.")
	terrain.set_run_seed(77123)
	var ordinary_pack := load("res://content/biome_packs/ordinary_taiga.tres") as BiomeContentPack
	var previous_landmark_row := -999
	var cadence_count := 0
	for row: int in range(2, 41):
		var center := terrain.call("_landmark_center_for_row", row, ordinary_pack) as Vector2
		var coordinate := Vector2i(floori(center.x / terrain.chunk_size), row)
		if terrain.call("_should_place_landmark", coordinate, ordinary_pack):
			if previous_landmark_row > -900:
				_expect(row - previous_landmark_row == ordinary_pack.landmark_period, "Landmark cadence drifted away from the authored biome period.")
			previous_landmark_row = row
			cadence_count += 1
			var route_distance := absf(center.x - float(terrain.call("_route_center_x", center.y)))
			_expect(route_distance >= 8.4 and route_distance <= 13.6, "Landmark was not staged at the readable edge of the expedition route.")
	_expect(cadence_count >= 3, "The finite region produced too few controlled landmark opportunities.")
	var region_center_z := ordinary_pack.region_south + ordinary_pack.region_length * 0.5
	var interior_height := terrain.get_height_at_global(Vector3(0.0, 0.0, region_center_z))
	var boundary_point := Vector3(ordinary_pack.region_half_width * 0.98, 0.0, region_center_z)
	var boundary_height := terrain.get_height_at_global(boundary_point)
	_expect(boundary_height > interior_height + ordinary_pack.boundary_height * 0.45, "The finite map edge is not closed by its authored mountain ring.")
	_expect(terrain.is_inside_playable_region(Vector3.ZERO) and not terrain.is_inside_playable_region(Vector3(ordinary_pack.region_half_width * 1.3, 0.0, region_center_z)), "Finite region containment does not distinguish its playable interior from the exterior.")
	_expect(not terrain.call("_chunk_intersects_region", Vector2i(80, 80)), "Streaming still accepts chunks far beyond the finite region.")
	var valley_context := terrain.get_environment_context(Vector3(float(terrain.call("_route_center_x", 240.0)), 0.0, 240.0))
	var rim_context := terrain.get_environment_context(boundary_point)
	_expect(StringName(valley_context.get("zone_id")) in [&"river_valley", &"dense_forest", &"basin"], "The route interior has no coherent lowland landscape zone.")
	_expect(StringName(rim_context.get("zone_id")) == &"boundary" and float(rim_context.get("exposure")) > float(valley_context.get("exposure")), "The mountain rim is not exposed as a distinct weather zone.")
	var far_z := 240.0
	var route_x := float(terrain.call("_route_center_x", far_z))
	var route_height := terrain.get_height_at_global(Vector3(route_x, 0, far_z))
	var shoulder_height := terrain.get_height_at_global(Vector3(route_x + 18.0, 0, far_z))
	_expect(route_height < shoulder_height, "The expedition route no longer forms a navigable valley through the streamed world.")
	var target := Node3D.new()
	add_child(target)
	target.global_position = Vector3(95, 0, 95)
	terrain.setup(target)
	var horizon := terrain.get_node("BiomeHorizon") as Node3D
	var expected_horizon_position := Vector3(0.0, 0.0, region_center_z)
	_expect(horizon.position.is_equal_approx(expected_horizon_position), "Finite-region horizon is not anchored to the authored map centre.")
	for _frame in 40:
		await get_tree().process_frame
	var anchored_horizon_position := horizon.global_position
	target.global_position += Vector3(1.0, 0.0, 1.0)
	terrain.call("_process", 1.0 / 60.0)
	_expect(horizon.global_position.is_equal_approx(anchored_horizon_position), "Distant mountains still move with the player camera.")
	_expect(terrain.get_loaded_chunk_count() >= 4, "Streaming terrain did not page chunks around a moving player.")
	var maximum_visual_chunks := int(pow(float(terrain.visual_radius * 2 + 1), 2.0))
	_expect(terrain.get_loaded_chunk_count() <= maximum_visual_chunks, "Streaming terrain exceeded its bounded visual working set.")
	_expect(terrain.get_collision_chunk_count() <= int(pow(float(terrain.collision_radius * 2 + 1), 2.0)), "Distant terrain retained expensive collision meshes.")
	_expect(terrain.get_distant_chunk_count() > 0, "Streaming terrain did not create the low-detail horizon ring.")
	for body: StaticBody3D in terrain.get_loaded_chunk_nodes():
		if int(body.get_meta(&"terrain_detail_tier", 0)) == 0:
			_expect(body.get_node_or_null("Collision") == null, "A horizon-only chunk still owns collision.")
	var center_chunk := terrain.get_loaded_chunk_nodes().filter(func(body: StaticBody3D) -> bool: return int(body.get_meta(&"terrain_detail_tier", 0)) == 2).front() as StaticBody3D
	var center_collision := center_chunk.get_node_or_null("Collision") as CollisionShape3D
	_expect(center_collision != null and center_collision.shape.get_faces().size() <= 3500, "Near terrain collision exceeded its bounded physics mesh budget.")
	terrain.set_world_phase(ExpeditionTerrain.PHASE_MYCELIAL)
	_expect(terrain.get_world_phase() == ExpeditionTerrain.PHASE_MYCELIAL, "Consumable world phase was not applied to terrain generation.")
	_validate_ecology_compositions(terrain)
	target.free()
	terrain.free()


func _validate_ecology_compositions(terrain: ExpeditionTerrain) -> void:
	var phase_paths := [
		"res://content/world_phases/ordinary_world.tres",
		"res://content/world_phases/mycelial_choir.tres",
		"res://content/world_phases/crimson_hunt.tres",
		"res://content/world_phases/glass_frost.tres",
		"res://content/world_phases/ashen_silence.tres",
		"res://content/world_phases/mirror_flood.tres",
		"res://content/world_phases/root_dream.tres",
		"res://content/world_phases/distant_heart.tres",
	]
	var families: Dictionary[StringName, bool] = {}
	var key_lights: Dictionary[Color, bool] = {}
	var motion_signatures: Dictionary[String, bool] = {}
	var route_signatures: Dictionary[String, bool] = {}
	var boundary_signatures: Dictionary[String, bool] = {}
	var expected_poi_focal_nodes := [
		"WeatheredCedarMarker", "ListeningBellCap", "WarmBoneWithoutBeast", "FrozenMemorySlab_00",
		"HalfErasedTentSkin", "StillWaterEye", "RootMouthDarkness", "BrotherArc_-1",
	]
	for path: String in phase_paths:
		var phase := load(path) as WorldPhaseDefinition
		var pack := phase.content_pack
		_expect(pack != null, "%s has no content pack." % path)
		if pack == null:
			continue
		_expect(not pack.composition_family.is_empty(), "%s has no authored ecology composition." % pack.id)
		families[pack.composition_family] = true
		key_lights[phase.visual_profile.primary_light_color] = true
		motion_signatures["%.3f:%.3f" % [pack.ecology_motion_strength, pack.ecology_motion_speed]] = true
		route_signatures["%.2f:%.2f:%.2f:%d" % [pack.route_width, pack.route_wander_scale, pack.route_relief_scale, pack.vista_period_chunks]] = true
		boundary_signatures["%d:%.0f:%.0f:%.0f" % [pack.boundary_family, pack.region_half_width, pack.region_length, pack.boundary_height]] = true
		_expect(pack.region_length >= 700.0 and pack.region_half_width >= 300.0, "%s is too small to support a substantial finite expedition." % pack.id)
		_expect(phase.visual_profile.ambient_energy <= 0.72, "%s flattens geometry with excessive ambient light." % phase.id)
		terrain.apply_world_phase(phase)
		var body := StaticBody3D.new()
		terrain.add_child(body)
		var rng := RandomNumberGenerator.new()
		rng.seed = 81173 + pack.ecology_family
		terrain.call("_add_ecology_composition", body, Vector2i(0, 5), rng, pack)
		var composition := body.get_child(0) if body.get_child_count() > 0 else null
		_expect(composition != null and composition.get_meta(&"composition_family", &"") == pack.composition_family, "%s did not build its authored composition." % pack.id)
		_expect(composition != null and composition.get_child_count() >= 5, "%s composition is too weak to form a readable silhouette." % pack.id)
		body.free()
		var found_primary_crowns := false
		var found_secondary_crowns := false
		var found_primary_geology := false
		var found_secondary_geology := false
		# Patch noise may deliberately leave one chunk open. Sample several authored
		# landscape beats so the test checks the biome vocabulary, not carpet density.
		for sample_index: int in 4:
			var scatter_body := StaticBody3D.new()
			terrain.add_child(scatter_body)
			var scatter_rng := RandomNumberGenerator.new()
			scatter_rng.seed = 19271 + pack.ecology_family * 313 + sample_index * 917
			var sample_coordinate := Vector2i(pack.ecology_family + sample_index * 3 - 3, 7 + sample_index * 2)
			terrain.call("_add_tree_multimeshes", scatter_body, sample_coordinate, scatter_rng, 36)
			terrain.call("_add_rock_multimesh", scatter_body, sample_coordinate, scatter_rng, 28)
			_expect(scatter_body.get_child_count() <= 5, "%s scatter escaped its bounded MultiMesh draw-pool budget." % pack.id)
			var primary_crowns := scatter_body.get_node_or_null("VegetationCrownsPrimary_%d" % pack.vegetation_family) as MultiMeshInstance3D
			var secondary_crowns := scatter_body.get_node_or_null("VegetationCrownsSecondary_%d" % pack.vegetation_family) as MultiMeshInstance3D
			var primary_geology := scatter_body.get_node_or_null("GeologyPrimary_%d" % pack.geology_family) as MultiMeshInstance3D
			var secondary_geology := scatter_body.get_node_or_null("GeologySecondary_%d" % pack.geology_family) as MultiMeshInstance3D
			found_primary_crowns = found_primary_crowns or (primary_crowns != null and primary_crowns.multimesh.instance_count > 0)
			found_secondary_crowns = found_secondary_crowns or (secondary_crowns != null and secondary_crowns.multimesh.instance_count > 0)
			found_primary_geology = found_primary_geology or (primary_geology != null and primary_geology.multimesh.instance_count > 0)
			found_secondary_geology = found_secondary_geology or (secondary_geology != null and secondary_geology.multimesh.instance_count > 0)
			scatter_body.free()
		_expect(found_primary_crowns, "%s lost its primary vegetation silhouette family." % pack.id)
		_expect(found_secondary_crowns, "%s has no secondary vegetation silhouette family." % pack.id)
		_expect(found_primary_geology, "%s lost its primary geology silhouette family." % pack.id)
		_expect(found_secondary_geology, "%s has no secondary geology silhouette family." % pack.id)
		var poi_body := StaticBody3D.new()
		terrain.add_child(poi_body)
		var poi_rng := RandomNumberGenerator.new()
		poi_rng.seed = 70123 + pack.ecology_family * 577
		terrain.call("_add_point_of_interest", poi_body, Vector2i(pack.ecology_family - 3, 9), poi_rng)
		var expected_focal_name: String = expected_poi_focal_nodes[pack.ecology_family]
		_expect(poi_body.find_child(expected_focal_name, true, false) != null, "%s still lacks a unique authored POI focal scene." % pack.id)
		poi_body.free()
	_expect(families.size() == phase_paths.size(), "Worlds reuse ecology compositions instead of owning distinct spatial motifs.")
	_expect(key_lights.size() == phase_paths.size(), "Worlds reuse the same key light instead of owning distinct lighting direction and color.")
	_expect(motion_signatures.size() == phase_paths.size(), "Worlds reuse one vegetation motion profile.")
	_expect(route_signatures.size() == phase_paths.size(), "Worlds reuse one route rhythm instead of owning distinct navigation geometry.")
	_expect(boundary_signatures.size() == phase_paths.size(), "Worlds reuse one finite-map boundary instead of owning distinct enclosing landscapes.")


func _create_scatter() -> BiomeDressingScatter:
	var scatter := BiomeDressingScatter.new()
	scatter.conifer_count = 3
	scatter.broadleaf_count = 2
	scatter.snag_count = 1
	scatter.rock_count = 3
	scatter.log_count = 1
	scatter.distant_ridge_count = 0
	scatter.terrain_mound_count = 0
	add_child(scatter)
	return scatter


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip biome generation test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip biome generation test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
