class_name ShelterLevel
extends Node3D

@onready var player: FirstPersonController = %Player
@onready var cooking_orchestrator: CookingOrchestrator = %CookingOrchestrator
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
@onready var forest_trail: Node3D = $ForestTrail
@onready var deep_grove: Node3D = $DeepGrove
@onready var shelter_progression_visuals: ShelterProgressionVisuals = %ShelterProgressionVisuals
@onready var investigation_board: InvestigationBoard = %InvestigationBoard
@onready var spore_tide: SporeTideOrchestrator = deep_grove.get_node("SporeTideOrchestrator") as SporeTideOrchestrator


func _ready() -> void:
	for node: Node in find_children("*", "CookingToolComponent", true, false):
		(node as CookingToolComponent).setup(cooking_orchestrator)
	for node: Node in find_children("*", "PhysicalCookingStationComponent", true, false):
		(node as PhysicalCookingStationComponent).setup(cooking_orchestrator)
	cooking_station_visuals.setup(cooking_orchestrator)
	cooking_station_audio.setup(cooking_orchestrator)
	hypothesis_orchestrator.setup(knowledge_orchestrator)
	game_loop_orchestrator.setup(objective_orchestrator, cooking_orchestrator, expedition_clock, knowledge_orchestrator)
	game_loop_orchestrator.route_unlock_changed.connect(_on_route_unlock_changed)
	shelter_progression_visuals.setup(game_loop_orchestrator)
	investigation_board.setup(game_loop_orchestrator)
	spore_tide.setup(player)
	_on_route_unlock_changed(game_loop_orchestrator.route_unlocked)
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
	(forest_trail.get_node("SporeRoute/VisionGate") as SimplePortal).traversed.connect(game_loop_orchestrator.record_grove_entered)
	forest_trail.set_spore_vision_active(false)
	expedition_clock.phase_changed.connect(forest_clearing.apply_phase)
	stealth_orchestrator.setup(player, [forest_clearing.listener])
	player.distraction_created.connect(_on_distraction_created)


func get_player() -> FirstPersonController:
	return player


func get_cooking_orchestrator() -> CookingOrchestrator:
	return cooking_orchestrator


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


func setup_visual_environment(world_environment: WorldEnvironment) -> void:
	biome_visual_controller.setup(world_environment)


func _on_distraction_created(projectile: DistractionProjectile) -> void:
	stealth_orchestrator.connect_noise_emitter(projectile.noise_emitter)


func _on_route_unlock_changed(is_unlocked: bool) -> void:
	deep_grove_gate.set_locked(not is_unlocked)


func apply_gameplay_channels(channels: Dictionary[StringName, float]) -> void:
	var spore_vision_active := float(channels.get(&"spore_vision", 0.0)) > 0.1
	hidden_mycelium.visible = spore_vision_active
	player.set_spore_vision_active(spore_vision_active)
	player.set_spore_resistance(float(channels.get(&"spore_resistance", 0.0)))
	forest_trail.set_spore_vision_active(spore_vision_active)
	deep_grove.set_spore_vision_active(spore_vision_active)
	game_loop_orchestrator.set_effect_channels(channels)
	spore_tide.apply_gameplay_channels(channels)
