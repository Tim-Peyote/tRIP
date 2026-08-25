extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var terrain := ExpeditionTerrain.new()
	add_child(terrain)
	var visuals := BiomeVisualController.new()
	add_child(visuals)
	var environment_node := WorldEnvironment.new()
	environment_node.environment = Environment.new()
	add_child(environment_node)
	visuals.shelter_profile = load("res://presentation/biomes/shelter_visual_profile.tres") as BiomeVisualProfile
	visuals.forest_profile = load("res://presentation/biomes/forest_visual_profile.tres") as BiomeVisualProfile
	visuals.mycelial_profile = load("res://presentation/biomes/mycelial_visual_profile.tres") as BiomeVisualProfile
	visuals.setup(environment_node)
	var orchestrator := WorldPhaseOrchestrator.new()
	add_child(orchestrator)
	orchestrator.setup(terrain, visuals)
	var definitions := orchestrator.get_definitions()
	_expect(definitions.size() == 8, "World catalog must contain exactly eight designed phases.")
	var ids: Dictionary[StringName, bool] = {}
	var content_signatures: Dictionary[String, bool] = {}
	var ecology_families: Dictionary[int, bool] = {}
	var vegetation_families: Dictionary[int, bool] = {}
	var geology_families: Dictionary[int, bool] = {}
	for index in definitions.size():
		var definition: WorldPhaseDefinition = definitions[index]
		_expect(definition.order == index, "World phases are not ordered for progression.")
		_expect(not ids.has(definition.id), "World phase IDs are not unique.")
		_expect(definition.visual_profile != null, "World phase has no visual profile: %s" % definition.id)
		_expect(definition.content_pack != null, "World phase has no biome content pack: %s" % definition.id)
		if definition.content_pack != null:
			var signature := definition.content_pack.get_generation_signature()
			_expect(not content_signatures.has(signature), "Two worlds share one content-pack signature: %s" % signature)
			content_signatures[signature] = true
			ecology_families[definition.content_pack.ecology_family] = true
			vegetation_families[definition.content_pack.vegetation_family] = true
			geology_families[definition.content_pack.geology_family] = true
		ids[definition.id] = true
		orchestrator.set_developer_phase(definition.id)
		_expect(orchestrator.get_current() == definition, "Developer switching failed for %s" % definition.id)
		var expected_terrain_phase := ExpeditionTerrain.PHASE_ORDINARY if definition.is_baseline() else definition.id
		_expect(terrain.get_world_phase() == expected_terrain_phase, "Terrain did not receive phase %s" % definition.id)
		if definition.content_pack != null:
			var terrain_signature := terrain.get_loaded_ecology_signature()
			_expect(terrain_signature.contains("VegetationCrownsPrimary_%d" % definition.content_pack.vegetation_family), "Terrain did not instantiate the phase vegetation family.")
			_expect(terrain_signature.contains("GeologyPrimary_%d" % definition.content_pack.geology_family), "Terrain did not instantiate the phase geology family.")
			_expect(terrain_signature.contains("Groundcover_%d" % definition.content_pack.ecology_family), "Every world must instantiate its own groundcover family.")
			var accent_body := StaticBody3D.new()
			terrain.add_child(accent_body)
			var accent_rng := RandomNumberGenerator.new()
			accent_rng.seed = 48017 + definition.content_pack.ecology_family * 977
			var accent_z := 225.0
			var accent_route_x := float(terrain.call("_route_center_x", accent_z))
			var accent_coordinate := Vector2i(floori(accent_route_x / terrain.chunk_size), 7)
			var accent_center := Vector3((float(accent_coordinate.x) + 0.5) * terrain.chunk_size, 0.0, accent_z)
			var accent_zone := int(terrain.get_environment_context(accent_center).get("zone", ExpeditionTerrain.LandscapeZone.DENSE_FOREST))
			(terrain.get("_decor_exclusion_centers") as Array).clear()
			terrain.call("_add_zone_accent_cluster", accent_body, accent_coordinate, accent_rng, definition.content_pack, accent_zone)
			_expect(accent_body.get_child_count() == 1 and String(accent_body.get_child(0).name).begins_with("ZoneAccent_%d_" % definition.content_pack.ecology_family), "World %s must build an art-directed middle-ground accent family (children: %d, zone: %d, coordinate: %s)." % [definition.id, accent_body.get_child_count(), accent_zone, accent_coordinate])
			accent_body.free()
			_expect(terrain.get_node_or_null("BiomeHorizon") != null, "World phase did not build a distant horizon layer.")
			_expect(terrain.get_node_or_null("BiomeAtmosphere") != null, "World phase did not build an atmospheric particle layer.")
			_expect(terrain.get_ambience_ecology_family() == definition.content_pack.ecology_family, "Biome ambience did not follow the active ecology family.")
			_expect(terrain.get_biome_ambience_layer_count() == 2, "Changing worlds leaked or duplicated biome ambience players.")
	_expect(ecology_families.size() == 8, "The eight worlds do not have eight distinct ecology families.")
	_expect(vegetation_families.size() == 8, "The eight worlds reuse a vegetation family.")
	_expect(geology_families.size() == 8, "The eight worlds reuse a geology family.")
	_expect(terrain.get_generated_mesh_cache_size() >= 20, "Authored biome meshes were not retained in the streaming cache.")
	orchestrator.clear_developer_override()
	orchestrator.apply_gameplay_channels({&"spore_vision": 1.0})
	_expect(orchestrator.get_current().id == &"phase.mycelial_choir", "Real consumable channel did not select the mycelial world.")
	_expect(not orchestrator.is_developer_override_active(), "Gameplay phase remained in developer override mode.")
	var metamorphosis := WorldMetamorphosisDirector.new()
	add_child(metamorphosis)
	metamorphosis.setup(orchestrator)
	orchestrator.set_developer_phase(&"phase.glass_frost")
	_expect(metamorphosis.is_transitioning(), "Changing world phase did not start a consciousness transition.")
	_expect(metamorphosis.get_target_phase_id() == &"phase.glass_frost", "Transition did not retain its target world.")
	metamorphosis.finish_immediately()
	_expect(not metamorphosis.is_transitioning(), "Transition could not settle cleanly.")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip world phase test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip world phase test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
