class_name ShelterLevel
extends Node3D

@onready var player: FirstPersonController = %Player
@onready var cooking_orchestrator: CookingOrchestrator = %CookingOrchestrator
@onready var recipe_knowledge_orchestrator: RecipeKnowledgeOrchestrator = %RecipeKnowledgeOrchestrator
@onready var hidden_mycelium: Node3D = %HiddenMycelium
@onready var cooking_station_visuals: CookingStationVisuals = %CookingStationVisuals
@onready var knowledge_orchestrator: KnowledgeOrchestrator = %KnowledgeOrchestrator
@onready var objective_orchestrator: ExpeditionObjectiveOrchestrator = %ObjectiveOrchestrator
@onready var expedition_clock: ExpeditionClock = %ExpeditionClock
@onready var forest_clearing: ForestClearingChunk = $ForestClearing
@onready var stealth_orchestrator: StealthOrchestrator = %StealthOrchestrator
@onready var cooking_station_audio: CookingStationAudio = %CookingStationAudio
@onready var hypothesis_orchestrator: HypothesisOrchestrator = %HypothesisOrchestrator
@onready var game_loop_orchestrator: GameLoopOrchestrator = %GameLoopOrchestrator
@onready var session_persistence: SessionPersistenceOrchestrator = %SessionPersistenceOrchestrator
@onready var deep_grove_gate: SimplePortal = $ForestClearing/DeepGroveGate
@onready var biome_visual_controller: BiomeVisualController = %BiomeVisualController
@onready var world_phase_orchestrator: WorldPhaseOrchestrator = %WorldPhaseOrchestrator
@onready var world_phase_developer_panel: WorldPhaseDeveloperPanel = %WorldPhaseDeveloperPanel
@onready var forest_trail: Node3D = $ForestTrail
@onready var deep_grove: Node3D = $DeepGrove
@onready var root_well: RootWellChunk = $RootWell
@onready var shelter_progression_visuals: ShelterProgressionVisuals = %ShelterProgressionVisuals
@onready var investigation_board: InvestigationBoard = %InvestigationBoard
@onready var spore_tide: SporeTideOrchestrator = deep_grove.get_node("SporeTideOrchestrator") as SporeTideOrchestrator
@onready var root_well_gate: SimplePortal = deep_grove.get_node("RootWellGate") as SimplePortal

var road_laboratory: RoadLaboratoryOrchestrator
var world_progression: WorldProgressionOrchestrator
var biome_hazard: BiomeHazardOrchestrator


func _ready() -> void:
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
	_setup_road_laboratory(terrain)
	_setup_biome_hazard(terrain)
	_setup_world_progression(terrain)
	world_phase_developer_panel.setup(
		world_phase_orchestrator,
		terrain,
		world_progression,
		biome_hazard,
		road_laboratory,
		player,
		expedition_clock,
		session_persistence
	)


func get_player() -> FirstPersonController:
	return player


func get_cooking_orchestrator() -> CookingOrchestrator:
	return cooking_orchestrator


func get_recipe_knowledge_orchestrator() -> RecipeKnowledgeOrchestrator:
	return recipe_knowledge_orchestrator


func get_knowledge_orchestrator() -> KnowledgeOrchestrator:
	return knowledge_orchestrator


func get_objective_orchestrator() -> ExpeditionObjectiveOrchestrator:
	return objective_orchestrator


func get_expedition_clock() -> ExpeditionClock:
	return expedition_clock


func get_stealth_orchestrator() -> StealthOrchestrator:
	return stealth_orchestrator


func get_hypothesis_orchestrator() -> HypothesisOrchestrator:
	return hypothesis_orchestrator


func get_game_loop_orchestrator() -> GameLoopOrchestrator:
	return game_loop_orchestrator


func get_session_persistence() -> SessionPersistenceOrchestrator:
	return session_persistence


func get_spore_tide() -> SporeTideOrchestrator:
	return spore_tide


func get_investigation_board() -> InvestigationBoard:
	return investigation_board


func get_root_pressure() -> RootPressureOrchestrator:
	return root_well.pressure


func get_road_laboratory() -> RoadLaboratoryOrchestrator:
	return road_laboratory


func get_world_progression() -> WorldProgressionOrchestrator:
	return world_progression


func get_biome_hazard() -> BiomeHazardOrchestrator:
	return biome_hazard


func initialize_new_session() -> void:
	_disable_legacy_shelter()
	biome_visual_controller.show_forest()
	world_progression.activate_session()
	road_laboratory.initialize_new_run(Vector3(0, 0, 11.5), Vector3(6.5, 0, 18.5))
	biome_hazard.activate_session()
	game_loop_orchestrator.narrative_notice_requested.emit(
		"ЯВЬ · ПЕРВЫЙ СЛЕД",
		"Комнаты здесь нет. Миколог оставил в камнях схему обряда: найди зелёное кольцо и восстанови дорожную лабораторию прямо в лесу."
	)


func apply_session_layout_after_load() -> void:
	_disable_legacy_shelter()
	biome_visual_controller.show_forest()
	world_progression.activate_session()
	biome_hazard.activate_session()


func apply_world_seed(value: int) -> void:
	for node: Node in find_children("*", "Node3D", true, false):
		if is_instance_valid(node) and node.has_method("set_run_seed"):
			node.call("set_run_seed", value)


func setup_visual_environment(world_environment: WorldEnvironment) -> void:
	biome_visual_controller.setup(world_environment)


func _setup_road_laboratory(terrain: ExpeditionTerrain) -> void:
	road_laboratory = RoadLaboratoryOrchestrator.new()
	road_laboratory.name = "RoadLaboratoryOrchestrator"
	add_child(road_laboratory)
	var portable_nodes: Array[Node] = []
	for path: NodePath in [
		NodePath("Table"), NodePath("Mooncap"), NodePath("Mortar"), NodePath("Cauldron"),
		NodePath("WaterJug"), NodePath("FireControl"), NodePath("Ladle"), NodePath("BottleRack"),
		NodePath("Rug"), NodePath("CookingStationVisuals"), NodePath("CookingStationAudio"),
		NodePath("ShelterProgressionVisuals"), NodePath("InvestigationBoard")
	]:
		portable_nodes.append(get_node(path))
	road_laboratory.setup(player, terrain, portable_nodes)
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
	var mortar_tool := road_laboratory.get_node("PortableLaboratory/Mortar/CookingToolComponent") as CookingToolComponent
	for definition: ContentDefinition in ContentDB.get_all():
		if definition is IngredientDefinition and definition.id not in mortar_tool.candidate_ingredient_ids:
			mortar_tool.candidate_ingredient_ids.append(definition.id)


func _setup_biome_hazard(terrain: ExpeditionTerrain) -> void:
	biome_hazard = BiomeHazardOrchestrator.new()
	biome_hazard.name = "BiomeHazardOrchestrator"
	add_child(biome_hazard)
	biome_hazard.setup(player, terrain, world_phase_orchestrator, road_laboratory)
	biome_hazard.overwhelmed.connect(func(definition: BiomeHazardDefinition, text: String) -> void:
		game_loop_orchestrator.narrative_notice_requested.emit(definition.display_name.to_upper(), text)
	)


func _disable_legacy_shelter() -> void:
	for node_path: NodePath in [
		NodePath("Architecture"), NodePath("ShelterDressing"), NodePath("Lighting/Lamp"), NodePath("ForestDoor")
	]:
		_set_branch_active(get_node(node_path), false)
	_set_branch_active(forest_clearing.get_node("ReturnPortal"), false)
	_set_branch_active(forest_clearing.get_node("DeepGroveGate"), false)
	_set_branch_active(forest_trail.get_node("ReturnPortal"), false)
	_set_branch_active(forest_trail.get_node("SporeRoute/VisionGate"), false)
	_set_branch_active(root_well_gate, false)


func _set_branch_active(branch: Node, value: bool) -> void:
	if branch is Node3D:
		(branch as Node3D).visible = value
	branch.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	for node: Node in branch.find_children("*", "CollisionShape3D", true, false):
		(node as CollisionShape3D).set_deferred("disabled", not value)
	for node: Node in branch.find_children("*", "InteractableComponent", true, false):
		(node as InteractableComponent).enabled = value


func _on_distraction_created(projectile: DistractionProjectile) -> void:
	stealth_orchestrator.connect_noise_emitter(projectile.noise_emitter)


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
