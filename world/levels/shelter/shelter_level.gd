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


func _ready() -> void:
	for node: Node in find_children("*", "CookingToolComponent", true, false):
		(node as CookingToolComponent).setup(cooking_orchestrator)
	for node: Node in find_children("*", "PhysicalCookingStationComponent", true, false):
		(node as PhysicalCookingStationComponent).setup(cooking_orchestrator)
	cooking_station_visuals.setup(cooking_orchestrator)
	cooking_station_audio.setup(cooking_orchestrator)
	hypothesis_orchestrator.setup(knowledge_orchestrator)
	for node: Node in find_children("*", "HarvestableIngredient", true, false):
		var ingredient := node as HarvestableIngredient
		ingredient.observed.connect(knowledge_orchestrator.observe)
		ingredient.harvested.connect(knowledge_orchestrator.record_harvest)
		if forest_clearing.is_ancestor_of(ingredient):
			ingredient.harvested.connect(objective_orchestrator.record_harvest)
	var return_portal := forest_clearing.get_node("ReturnPortal") as SimplePortal
	return_portal.traversed.connect(objective_orchestrator.record_return)
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


func _on_distraction_created(projectile: DistractionProjectile) -> void:
	stealth_orchestrator.connect_noise_emitter(projectile.noise_emitter)


func apply_gameplay_channels(channels: Dictionary[StringName, float]) -> void:
	hidden_mycelium.visible = float(channels.get(&"spore_vision", 0.0)) > 0.1
