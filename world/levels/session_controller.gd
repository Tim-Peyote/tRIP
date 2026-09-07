class_name SessionController
extends Node3D

@onready var player: FirstPersonController = _resolve_scene_node("Player")
@onready var cooking_orchestrator: CookingOrchestrator = _resolve_scene_node("CookingOrchestrator")
@onready var recipe_knowledge_orchestrator: RecipeKnowledgeOrchestrator = _resolve_scene_node("RecipeKnowledgeOrchestrator")
@onready var cooking_station_visuals: CookingStationVisuals = _resolve_scene_node("CookingStationVisuals")
@onready var knowledge_orchestrator: KnowledgeOrchestrator = _resolve_scene_node("KnowledgeOrchestrator")
@onready var objective_orchestrator: ExpeditionObjectiveOrchestrator = _resolve_scene_node("ObjectiveOrchestrator")
@onready var expedition_clock: ExpeditionClock = _resolve_scene_node("ExpeditionClock")
@onready var stealth_orchestrator: StealthOrchestrator = _resolve_scene_node("StealthOrchestrator")
@onready var cooking_station_audio: CookingStationAudio = _resolve_scene_node("CookingStationAudio")
@onready var hypothesis_orchestrator: HypothesisOrchestrator = _resolve_scene_node("HypothesisOrchestrator")
@onready var game_loop_orchestrator: GameLoopOrchestrator = _resolve_scene_node("GameLoopOrchestrator")
@onready var session_persistence: SessionPersistenceOrchestrator = _resolve_scene_node("SessionPersistenceOrchestrator")
@onready var biome_visual_controller: BiomeVisualController = _resolve_scene_node("BiomeVisualController")
@onready var world_phase_orchestrator: WorldPhaseOrchestrator = _resolve_scene_node("WorldPhaseOrchestrator")
@onready var world_phase_developer_panel: WorldPhaseDeveloperPanel = _resolve_scene_node("WorldPhaseDeveloperPanel")
@onready var shelter_progression_visuals: ShelterProgressionVisuals = _resolve_scene_node("ShelterProgressionVisuals")
@onready var investigation_board: InvestigationBoard = _resolve_scene_node("InvestigationBoard")
@onready var spore_tide: SporeTideOrchestrator = _resolve_scene_node("SporeTideOrchestrator") as SporeTideOrchestrator

var road_laboratory: RoadLaboratoryOrchestrator
var world_progression: WorldProgressionOrchestrator
var biome_hazard: BiomeHazardOrchestrator
var biome_population: BiomePopulationOrchestrator
var weather: WeatherOrchestrator
var physical_showcase: PhysicalInteractionShowcase
var cooking_station_progression_visuals: CookingStationProgressionVisuals
var map_exploration: MapExplorationOrchestrator


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


func get_road_laboratory() -> RoadLaboratoryOrchestrator:
	return road_laboratory


func get_world_progression() -> WorldProgressionOrchestrator:
	return world_progression


func get_biome_hazard() -> BiomeHazardOrchestrator:
	return biome_hazard


func get_biome_population() -> BiomePopulationOrchestrator:
	return biome_population


func get_weather() -> WeatherOrchestrator:
	return weather


func get_map_exploration() -> MapExplorationOrchestrator:
	return map_exploration


func get_expedition_terrain() -> ExpeditionTerrain:
	return $ExpeditionTerrain as ExpeditionTerrain


func initialize_new_session() -> void:
	biome_visual_controller.show_forest_immediate()
	world_progression.activate_session()
	road_laboratory.initialize_new_run(Vector3(0, 0, 11.5), Vector3(6.5, 0, 18.5))
	biome_hazard.activate_session()
	game_loop_orchestrator.narrative_notice_requested.emit(
		"ЯВЬ · ПЕРВЫЙ СЛЕД",
		"Комнаты здесь нет. Миколог оставил в камнях схему обряда: найди зелёное кольцо и восстанови дорожную лабораторию прямо в лесу."
	)


func apply_session_layout_after_load() -> void:
	biome_visual_controller.show_forest_immediate()
	world_progression.activate_session()
	biome_hazard.activate_session()


func apply_world_seed(value: int) -> void:
	for node: Node in find_children("*", "Node3D", true, false):
		if is_instance_valid(node) and node.has_method("set_run_seed"):
			node.call("set_run_seed", value)


func setup_visual_environment(world_environment: WorldEnvironment) -> void:
	biome_visual_controller.setup(world_environment)
	biome_visual_controller.setup_clock(expedition_clock)
	biome_visual_controller.setup_reflection_target(player)
	weather = get_node_or_null("WeatherOrchestrator") as WeatherOrchestrator
	if weather == null:
		weather = (load("res://features/weather/weather_orchestrator.tscn") as PackedScene).instantiate() as WeatherOrchestrator
		add_child(weather)
	var terrain := $ExpeditionTerrain as ExpeditionTerrain
	weather.setup(world_environment, player, terrain)
	weather.wetness_changed.connect(terrain.set_weather_wetness)
	terrain.set_weather_wetness(weather.wetness)
	world_phase_orchestrator.phase_changed.connect(weather.apply_world_phase)
	weather.apply_world_phase(world_phase_orchestrator.get_current())
	biome_visual_controller.atmosphere_baseline_changed.connect(weather.set_atmosphere_baseline)
	biome_visual_controller.postprocess_baseline_changed.connect(weather.set_postprocess_baseline)
	weather.state_changed.connect(biome_visual_controller.set_weather_state)
	weather.state_changed.connect(terrain.set_weather_state)
	terrain.set_weather_state(weather.state, weather.get_state_title(), weather.intensity)
	world_phase_developer_panel.setup_weather(weather)


func _setup_map_exploration(terrain: ExpeditionTerrain) -> void:
	map_exploration = MapExplorationOrchestrator.new()
	map_exploration.name = "MapExplorationOrchestrator"
	add_child(map_exploration)
	map_exploration.setup(player, terrain, world_phase_orchestrator)
	map_exploration.exploration_changed.connect(func(_phase_id: StringName) -> void:
		session_persistence.request_autosave(&"map_exploration")
	)


func _setup_biome_hazard(terrain: ExpeditionTerrain) -> void:
	biome_hazard = BiomeHazardOrchestrator.new()
	biome_hazard.name = "BiomeHazardOrchestrator"
	add_child(biome_hazard)
	biome_hazard.setup(player, terrain, world_phase_orchestrator, road_laboratory)
	biome_hazard.overwhelmed.connect(func(definition: BiomeHazardDefinition, text: String) -> void:
		player.vitals.apply_damage(8.0, definition.id)
		game_loop_orchestrator.narrative_notice_requested.emit(definition.display_name.to_upper(), text)
	)


func _on_player_incapacitated(source: StringName) -> void:
	var terrain := $ExpeditionTerrain as ExpeditionTerrain
	var safe_position := Vector3(0.0, 0.0, 10.5)
	safe_position.y = terrain.get_height_at_global(safe_position) + 0.18
	player.global_position = safe_position
	player.velocity = Vector3.ZERO
	player.vitals.recover_after_incapacitation()
	game_loop_orchestrator.narrative_notice_requested.emit(
		"ТЫ ПРИШЁЛ В СЕБЯ У ОЧАГА",
		"Причина: %s. Последний пищевой эффект утрачен; тело ослаблено, токсическая и споровая нагрузка сохранились." % String(source)
	)
	session_persistence.request_autosave(&"incapacitation_recovery")


func _setup_biome_population(terrain: ExpeditionTerrain) -> void:
	biome_population = BiomePopulationOrchestrator.new()
	biome_population.name = "BiomePopulationOrchestrator"
	add_child(biome_population)
	biome_population.setup(terrain, player, world_phase_orchestrator)


func _setup_physical_interaction(terrain: ExpeditionTerrain) -> void:
	physical_showcase = PhysicalInteractionShowcase.new()
	physical_showcase.name = "PhysicalInteractionShowcase"
	add_child(physical_showcase)
	physical_showcase.setup(terrain)


func _on_distraction_created(projectile: DistractionProjectile) -> void:
	stealth_orchestrator.connect_noise_emitter(projectile.noise_emitter)


func _resolve_scene_node(node_name: String) -> Node:
	return find_child(node_name, true, false)

func get_root_pressure() -> RootPressureOrchestrator:
	return get_node_or_null("RootPressureOrchestrator") as RootPressureOrchestrator


func apply_gameplay_channels(channels: Dictionary[StringName, float]) -> void:
	world_phase_orchestrator.apply_gameplay_channels(channels)
	player.set_spore_vision_active(float(channels.get(&"spore_vision", 0.0)) > 0.1)
	player.set_spore_resistance(float(channels.get(&"spore_resistance", 0.0)))
	player.set_crimson_drive(float(channels.get(&"crimson_drive", 0.0)))
	game_loop_orchestrator.set_effect_channels(channels)
