extends SessionController

# Production composition. Shared services depend only on SessionController.
func _ready() -> void:
	ContentDB.rebuild()
	var terrain := get_expedition_terrain()
	terrain.setup(player)
	world_phase_orchestrator.setup(terrain, biome_visual_controller)
	for node: Node in find_children("*", "CookingToolComponent", true, false):
		(node as CookingToolComponent).setup(cooking_orchestrator)
	for node: Node in find_children("*", "PhysicalCookingStationComponent", true, false):
		(node as PhysicalCookingStationComponent).setup(cooking_orchestrator)
	cooking_station_visuals.setup(cooking_orchestrator)
	cooking_station_audio.setup(cooking_orchestrator)
	recipe_knowledge_orchestrator.setup(cooking_orchestrator)
	hypothesis_orchestrator.setup(knowledge_orchestrator)
	game_loop_orchestrator.setup(objective_orchestrator, cooking_orchestrator, expedition_clock, knowledge_orchestrator)
	shelter_progression_visuals.setup(game_loop_orchestrator)
	investigation_board.setup(game_loop_orchestrator)
	stealth_orchestrator.setup(player, [])
	player.distraction_created.connect(_on_distraction_created)
	player.vitals.incapacitated.connect(_on_player_incapacitated)
	_setup_road_laboratory(terrain)
	_setup_biome_hazard(terrain)
	_setup_world_progression(terrain)
	_setup_biome_population(terrain)
	_setup_physical_interaction(terrain)
	_setup_map_exploration(terrain)
	world_phase_developer_panel.setup(world_phase_orchestrator, terrain, world_progression, biome_hazard, road_laboratory, player, expedition_clock, session_persistence, biome_population)
	for node: Node in find_children("*", "HarvestableIngredient", true, false):
		var ingredient := node as HarvestableIngredient
		ingredient.observed.connect(knowledge_orchestrator.observe)
		ingredient.harvested.connect(knowledge_orchestrator.record_harvest)
	if get_parent() == get_tree().root:
		setup_visual_environment($WorldEnvironment)
		initialize_new_session()


func _setup_road_laboratory(terrain: ExpeditionTerrain) -> void:
	road_laboratory = RoadLaboratoryOrchestrator.new()
	road_laboratory.name = "RoadLaboratoryOrchestrator"
	add_child(road_laboratory)
	road_laboratory.setup_authored(player, terrain, $PortableLaboratory)
	cooking_station_progression_visuals = CookingStationProgressionVisuals.new()
	add_child(cooking_station_progression_visuals)
	cooking_station_progression_visuals.setup(cooking_orchestrator, $PortableLaboratory)
	road_laboratory.laboratory_entered.connect(objective_orchestrator.record_return)
	road_laboratory.autosave_requested.connect(session_persistence.request_autosave)


func _setup_world_progression(terrain: ExpeditionTerrain) -> void:
	world_progression = WorldProgressionOrchestrator.new()
	world_progression.name = "WorldProgressionOrchestrator"
	add_child(world_progression)
	world_progression.setup(world_phase_orchestrator, terrain, cooking_orchestrator, recipe_knowledge_orchestrator, game_loop_orchestrator)
	world_progression.autosave_requested.connect(session_persistence.request_autosave)
	terrain.biome_ingredient_harvested.connect(knowledge_orchestrator.record_harvest)
	terrain.biome_ingredient_observed.connect(knowledge_orchestrator.observe)
	for node: Node in $PortableLaboratory.find_children("*", "CookingToolComponent", true, false):
		var tool := node as CookingToolComponent
		for definition: ContentDefinition in ContentDB.get_all():
			if definition is IngredientDefinition and definition.id not in tool.candidate_ingredient_ids:
				tool.candidate_ingredient_ids.append(definition.id)


func get_root_pressure() -> RootPressureOrchestrator:
	return $RootPressureOrchestrator
