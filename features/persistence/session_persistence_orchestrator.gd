class_name SessionPersistenceOrchestrator
extends Node

signal saved(slot_id: int, reason: StringName)
signal loaded(slot_id: int)

var slot_id: int = 0
var _level: ShelterLevel
var _loop: GameLoopOrchestrator
var _collected_spawn_ids: Dictionary[StringName, bool] = {}
var _pending_reason: StringName = &"state_changed"
var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 0.45
	_timer.timeout.connect(save_now)
	add_child(_timer)


func setup(level: ShelterLevel, game_loop: GameLoopOrchestrator, value_slot_id: int) -> void:
	_level = level
	_loop = game_loop
	slot_id = value_slot_id
	level.player.inventory.changed.connect(func() -> void: request_autosave(&"inventory"))
	level.player.vitals.food_slots_changed.connect(func(_slots: Array[Dictionary]) -> void: request_autosave(&"metabolism"))
	level.player.vitals.damaged.connect(func(_amount: float, _source: StringName) -> void: request_autosave(&"health"))
	level.knowledge_orchestrator.entry_changed.connect(func(_id: StringName, _level_value: int) -> void: request_autosave(&"knowledge"))
	level.knowledge_orchestrator.clue_recorded.connect(func(_id: StringName, _clue: StringName, _count: int, _total: int) -> void: request_autosave(&"clue"))
	level.recipe_knowledge_orchestrator.recipe_learned.connect(func(_id: StringName, _name: String) -> void: request_autosave(&"recipe_learned"))
	game_loop.autosave_requested.connect(request_autosave)
	for node: Node in level.find_children("*", "HarvestableIngredient", true, false):
		var ingredient := node as HarvestableIngredient
		ingredient.harvested.connect(_on_harvested.bind(ingredient.get_spawn_id()))


func initialize_new() -> void:
	_collected_spawn_ids.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_loop.initialize_world_seed(rng.randi_range(1, 2147483646))
	_level.apply_world_seed(_loop.world_seed)
	_level.get_map_exploration().apply_save_data({})
	_level.initialize_new_session()
	save_now(&"new_game")


func load() -> bool:
	var data := SaveService.load_slot(slot_id)
	if data.is_empty():
		return false
	apply_save_data(data)
	loaded.emit(slot_id)
	return true


func request_autosave(reason: StringName = &"state_changed") -> void:
	_pending_reason = reason
	_timer.start()


func save_now(reason: StringName = &"") -> void:
	if _level == null:
		return
	var final_reason := reason if reason != &"" else _pending_reason
	if SaveService.save_slot(slot_id, capture_save_data()):
		saved.emit(slot_id, final_reason)


func capture_save_data() -> Dictionary:
	var player := _level.player
	return {
		"inventory": player.inventory.to_save_data(),
		"knowledge": _level.knowledge_orchestrator.to_save_data(),
		"objective": _level.objective_orchestrator.to_save_data(),
		"clock": _level.expedition_clock.to_save_data(),
		"cooking": _level.cooking_orchestrator.to_save_data(),
		"recipe_knowledge": _level.recipe_knowledge_orchestrator.to_save_data(),
		"toolbelt": player.toolbelt.to_save_data(),
		"vitals": player.vitals.to_save_data(),
		"game_loop": _loop.to_save_data(),
		"road_laboratory": _level.get_road_laboratory().to_save_data(),
		"world_progression": _level.get_world_progression().to_save_data(),
		"biome_hazard": _level.get_biome_hazard().to_save_data(),
		"map_exploration": _level.get_map_exploration().to_save_data(),
		"collected_spawn_ids": _collected_spawn_ids.keys().map(func(value: Variant) -> String: return String(value)),
		"player": {
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
			"yaw": player.rotation.y,
		},
	}


func apply_save_data(data: Dictionary) -> void:
	_level.apply_session_layout_after_load()
	_level.player.inventory.apply_save_data(data.get("inventory", []) as Array)
	_level.knowledge_orchestrator.apply_save_data(data.get("knowledge", {}) as Dictionary)
	_level.objective_orchestrator.apply_save_data(data.get("objective", {}) as Dictionary)
	_level.expedition_clock.apply_save_data(data.get("clock", {}) as Dictionary)
	_level.cooking_orchestrator.apply_save_data(data.get("cooking", {}) as Dictionary)
	_level.recipe_knowledge_orchestrator.apply_save_data(data.get("recipe_knowledge", {}) as Dictionary)
	_level.player.toolbelt.apply_save_data(data.get("toolbelt", {}) as Dictionary)
	_level.player.vitals.apply_save_data(data.get("vitals", {}) as Dictionary)
	_collected_spawn_ids.clear()
	for raw_id: Variant in data.get("collected_spawn_ids", []):
		_collected_spawn_ids[StringName(raw_id)] = true
	for node: Node in _level.find_children("*", "HarvestableIngredient", true, false):
		var ingredient := node as HarvestableIngredient
		if _collected_spawn_ids.has(ingredient.get_spawn_id()):
			ingredient.queue_free()
	_loop.apply_save_data(data.get("game_loop", {}) as Dictionary)
	_level.apply_world_seed(_loop.world_seed)
	var player_data := data.get("player", {}) as Dictionary
	var position_data: Array = player_data.get("position", []) as Array
	if position_data.size() == 3:
		_level.player.global_position = Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
	_level.player.rotation.y = float(player_data.get("yaw", 0.0))
	_level.get_world_progression().apply_save_data(data.get("world_progression", {}) as Dictionary)
	_level.get_biome_hazard().apply_save_data(data.get("biome_hazard", {}) as Dictionary)
	_level.get_map_exploration().apply_save_data(data.get("map_exploration", {}) as Dictionary)
	if data.has("road_laboratory"):
		_level.get_road_laboratory().apply_save_data(data.get("road_laboratory", {}) as Dictionary)
	else:
		_level.get_road_laboratory().migrate_legacy_save()


func _on_harvested(_item: ItemInstance, spawn_id: StringName) -> void:
	_collected_spawn_ids[spawn_id] = true
	request_autosave(&"harvest")
