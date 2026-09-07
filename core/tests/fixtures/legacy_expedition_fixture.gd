class_name LegacyExpeditionFixture
extends SessionController

# Archived prototype composition, used only by regression tests.
@onready var hidden_mycelium: Node3D = _resolve_scene_node("HiddenMycelium")
@onready var forest_clearing: ForestClearingChunk = get_node_or_null("ForestClearing")
@onready var deep_grove_gate: SimplePortal = get_node_or_null("ForestClearing/DeepGroveGate")
@onready var forest_trail: Node3D = get_node_or_null("ForestTrail")
@onready var deep_grove: Node3D = get_node_or_null("DeepGrove")
@onready var root_well: RootWellChunk = get_node_or_null("RootWell")
@onready var root_well_gate: SimplePortal = _resolve_scene_node("RootWellGate") as SimplePortal

func _ready() -> void:
	_disable_hidden_legacy_audio()
	($ProceduralAmbience as ProceduralAmbience).setup(player)
	var terrain := $ExpeditionTerrain as ExpeditionTerrain
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
	game_loop_orchestrator.route_unlock_changed.connect(_on_route_unlock_changed)
	shelter_progression_visuals.setup(game_loop_orchestrator)
	investigation_board.setup(game_loop_orchestrator)
	spore_tide.setup(player)
	spore_tide.exposure_changed.connect(player.vitals.set_spore_exposure)
	root_well.setup(game_loop_orchestrator, player)
	_on_route_unlock_changed(game_loop_orchestrator.route_unlocked)
	_on_root_well_plan_changed(game_loop_orchestrator.root_well_plan, "")
	for node: Node in find_children("*", "HarvestableIngredient", true, false):
		var ingredient := node as HarvestableIngredient
		ingredient.observed.connect(knowledge_orchestrator.observe)
		ingredient.harvested.connect(knowledge_orchestrator.record_harvest)
		if forest_clearing.is_ancestor_of(ingredient):
			ingredient.harvested.connect(objective_orchestrator.record_harvest)
		if deep_grove.is_ancestor_of(ingredient):
			ingredient.harvested.connect(game_loop_orchestrator.record_grove_harvest)
	var return_portal := forest_clearing.get_node("ReturnPortal") as SimplePortal
	return_portal.traversed.connect(objective_orchestrator.record_return)
	return_portal.traversed.connect(game_loop_orchestrator.record_second_return)
	return_portal.traversed.connect(biome_visual_controller.show_shelter)
	($ForestDoor as SimplePortal).traversed.connect(biome_visual_controller.show_forest)
	(forest_trail.get_node("ReturnPortal") as SimplePortal).traversed.connect(biome_visual_controller.show_forest)
	for clue: Node in forest_trail.get_clues():
		clue.discovered.connect(game_loop_orchestrator.record_trail_clue)
	for clue: Node in deep_grove.get_narrative_clues():
		clue.discovered.connect(game_loop_orchestrator.record_trail_clue)
	for clue: Node in root_well.get_narrative_clues():
		clue.discovered.connect(game_loop_orchestrator.record_trail_clue)
	(forest_trail.get_node("SporeRoute/VisionGate") as SimplePortal).traversed.connect(game_loop_orchestrator.record_grove_entered)
	root_well_gate.traversed.connect(game_loop_orchestrator.record_root_well_entered)
	game_loop_orchestrator.root_well_plan_changed.connect(_on_root_well_plan_changed)
	forest_trail.set_spore_vision_active(false)
	expedition_clock.phase_changed.connect(forest_clearing.apply_phase)
	stealth_orchestrator.setup(player, [forest_clearing.listener])
	player.distraction_created.connect(_on_distraction_created)
	player.vitals.incapacitated.connect(_on_player_incapacitated)
	_setup_road_laboratory(terrain)
	_setup_biome_hazard(terrain)
	_setup_world_progression(terrain)
	_setup_biome_population(terrain)
	_setup_physical_interaction(terrain)
	_setup_map_exploration(terrain)
	world_phase_developer_panel.setup(
		world_phase_orchestrator,
		terrain,
		world_progression,
		biome_hazard,
		road_laboratory,
		player,
		expedition_clock,
		session_persistence,
		biome_population
	)


func _setup_road_laboratory(terrain: ExpeditionTerrain) -> void:
	road_laboratory = RoadLaboratoryOrchestrator.new()
	road_laboratory.name = "RoadLaboratoryOrchestrator"
	add_child(road_laboratory)
	var portable_nodes: Array[Node] = []
	for path: NodePath in [
		NodePath("Table"), NodePath("Mooncap"), NodePath("Mortar"), NodePath("Cauldron"),
		NodePath("WashBasin"), NodePath("PrepBoard"), NodePath("WaterJug"), NodePath("FireControl"), NodePath("Ladle"), NodePath("BottleRack"),
		NodePath("KvassJug"), NodePath("SpiritFlask"), NodePath("PotCrane"), NodePath("Bellows"), NodePath("Hourglass"), NodePath("Distiller"), NodePath("ServingBowl"),
		NodePath("Rug"), NodePath("CookingStationVisuals"), NodePath("CookingStationAudio"),
		NodePath("ShelterProgressionVisuals"), NodePath("InvestigationBoard")
	]:
		portable_nodes.append(get_node(path))
	road_laboratory.setup(player, terrain, portable_nodes)
	cooking_station_progression_visuals = CookingStationProgressionVisuals.new()
	cooking_station_progression_visuals.name = "CookingStationProgressionVisuals"
	add_child(cooking_station_progression_visuals)
	cooking_station_progression_visuals.setup(cooking_orchestrator, road_laboratory.get_node("PortableLaboratory"))
	road_laboratory.laboratory_entered.connect(objective_orchestrator.record_return)
	road_laboratory.autosave_requested.connect(session_persistence.request_autosave)
	road_laboratory.metamorphosis_started.connect(func() -> void:
		game_loop_orchestrator.narrative_notice_requested.emit("ОБРЯД", "Пространство вспоминает форму полевой лаборатории. Воздух складывается вокруг огня.")
	)


func _setup_world_progression(terrain: ExpeditionTerrain) -> void:
	world_progression = WorldProgressionOrchestrator.new()
	world_progression.name = "WorldProgressionOrchestrator"
	add_child(world_progression)
	world_progression.setup(world_phase_orchestrator, terrain, cooking_orchestrator, recipe_knowledge_orchestrator, game_loop_orchestrator)
	world_progression.autosave_requested.connect(session_persistence.request_autosave)
	terrain.biome_ingredient_harvested.connect(knowledge_orchestrator.record_harvest)
	terrain.biome_ingredient_observed.connect(knowledge_orchestrator.observe)
	for node: Node in road_laboratory.get_node("PortableLaboratory").find_children("*", "CookingToolComponent", true, false):
		var preparation_tool := node as CookingToolComponent
		for definition: ContentDefinition in ContentDB.get_all():
			if definition is IngredientDefinition and definition.id not in preparation_tool.candidate_ingredient_ids:
				preparation_tool.candidate_ingredient_ids.append(definition.id)


func _disable_legacy_shelter() -> void:
	_disable_hidden_legacy_audio()
	# The authored room is not part of a real run. Its global forest recording
	# must not survive as an invisible first-biome layer over later worlds.
	($ProceduralAmbience as ProceduralAmbience).set_ambience_enabled(false)
	# The streamed expedition terrain replaces these prototype chunks in a real
	# session. Leaving their floors, walls, areas and creatures active produces
	# overlapping collision at the expedition spawn and can pin the player.
	for legacy_chunk: Node in [forest_clearing, forest_trail, deep_grove, root_well]:
		_set_branch_active(legacy_chunk, false)
	for node_path: NodePath in [
		NodePath("Architecture"), NodePath("ShelterDressing"), NodePath("Lighting/Lamp"), NodePath("ForestDoor")
	]:
		_set_branch_active(get_node(node_path), false)
	_set_branch_active(forest_clearing.get_node("ReturnPortal"), false)
	_set_branch_active(forest_clearing.get_node("DeepGroveGate"), false)
	_set_branch_active(forest_trail.get_node("ReturnPortal"), false)
	_set_branch_active(forest_trail.get_node("SporeRoute/VisionGate"), false)
	_set_branch_active(root_well_gate, false)


func _disable_hidden_legacy_audio() -> void:
	for branch: Node in [forest_trail, deep_grove, root_well]:
		for node: Node in branch.find_children("*", "SpatialForestEmitter", true, false):
			(node as SpatialForestEmitter).set_audio_active(false)


func _set_branch_active(branch: Node, value: bool) -> void:
	if branch is Node3D:
		(branch as Node3D).visible = value
	branch.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	for node: Node in branch.find_children("*", "CollisionShape3D", true, false):
		(node as CollisionShape3D).set_deferred("disabled", not value)
	for node: Node in branch.find_children("*", "InteractableComponent", true, false):
		(node as InteractableComponent).enabled = value


func _on_route_unlock_changed(is_unlocked: bool) -> void:
	deep_grove_gate.set_locked(not is_unlocked)


func apply_gameplay_channels(channels: Dictionary[StringName, float]) -> void:
	var spore_vision_active := float(channels.get(&"spore_vision", 0.0)) > 0.1
	world_phase_orchestrator.apply_gameplay_channels(channels)
	hidden_mycelium.visible = spore_vision_active
	player.set_spore_vision_active(spore_vision_active)
	player.set_spore_resistance(float(channels.get(&"spore_resistance", 0.0)))
	player.set_crimson_drive(float(channels.get(&"crimson_drive", 0.0)))
	forest_trail.set_spore_vision_active(spore_vision_active)
	root_well.set_spore_vision_active(spore_vision_active)
	deep_grove.set_spore_vision_active(spore_vision_active)
	game_loop_orchestrator.set_effect_channels(channels)
	spore_tide.apply_gameplay_channels(channels)


func _on_root_well_plan_changed(plan_id: StringName, _title: String) -> void:
	root_well_gate.set_locked(plan_id == &"")


func get_root_pressure() -> RootPressureOrchestrator:
	return root_well.pressure



func initialize_new_session() -> void:
	_disable_legacy_shelter()
	super.initialize_new_session()


func apply_session_layout_after_load() -> void:
	_disable_legacy_shelter()
	super.apply_session_layout_after_load()
