class_name GameLoopOrchestrator
extends Node

signal stage_changed(stage: int, objective_text: String)
signal result_ready(summary: Dictionary)
signal route_unlock_changed(is_unlocked: bool)
signal autosave_requested(reason: StringName)
signal narrative_notice_requested(title: String, text: String)

enum Stage { EXPEDITION, BREW, REWARD, DEEP_GROVE }

var stage: Stage = Stage.EXPEDITION
var route_unlocked: bool = false
var completed_cycles: int = 0
var mycologist_clues: Dictionary[StringName, bool] = {}
var spore_vision_active: bool = false
var deep_grove_entered: bool = false
var emberberry_collected: bool = false
var second_expedition_complete: bool = false
var counteragent_brewed: bool = false
var spore_quiet_active: bool = false
var _objective: ExpeditionObjectiveOrchestrator
var _cooking: CookingOrchestrator
var _clock: ExpeditionClock
var _knowledge: KnowledgeOrchestrator


func setup(
	objective: ExpeditionObjectiveOrchestrator,
	cooking: CookingOrchestrator,
	clock: ExpeditionClock,
	knowledge: KnowledgeOrchestrator
) -> void:
	_objective = objective
	_cooking = cooking
	_clock = clock
	_knowledge = knowledge
	objective.completed.connect(_on_expedition_returned)
	objective.objective_updated.connect(func(_text: String) -> void:
		if stage == Stage.EXPEDITION:
			stage_changed.emit(stage, get_objective_text())
	)
	cooking.result_created.connect(_on_cooking_result)
	_emit_state()


func get_objective_text() -> String:
	match stage:
		Stage.EXPEDITION:
			return _objective.get_objective_text() if _objective != null else "ВЫЛАЗКА"
		Stage.BREW:
			return "УБЕЖИЩЕ · приготовить чистый настой спорозрения"
		Stage.REWARD:
			return "ЦИКЛ ЗАВЕРШЁН · разобрать результаты"
		_:
			if mycologist_clues.has(&"mycologist.ring.surge_trace"):
				return "КООРДИНАТЫ НАЙДЕНЫ · подготовиться к корневому колодцу"
			if counteragent_brewed and spore_quiet_active:
				return "ТИХАЯ КРОВЬ · пережить споровый прилив и исследовать кольцо"
			if counteragent_brewed and spore_vision_active:
				return "СПОРОЗРЕНИЕ · рискнуть во время прилива ради скрытого следа"
			if counteragent_brewed:
				return "ВЫБОР ПРЕПАРАТА · спорозрение открывает путь, контрагент защищает"
			if second_expedition_complete:
				return "УБЕЖИЩЕ · исследовать тлеющую ягоду и карту миколога"
			if emberberry_collected:
				return "ОБРАЗЕЦ И СЛЕД ПОЛУЧЕНЫ · вернуться в убежище"
			if mycologist_clues.has(&"mycologist.camp.abandoned"):
				return "ЛАГЕРЬ МИКОЛОГА · найти тлеющую ягоду по его схеме"
			if deep_grove_entered:
				return "ГЛУБОКАЯ РОЩА · подняться к лагерю миколога"
			if mycologist_clues.has(&"mycologist.trail.spore_message"):
				return "СЛЕД МИКОЛОГА · войти в дышащую тропу"
			if spore_vision_active:
				return "СПОРОЗРЕНИЕ · искать запись на северной тропе"
			if mycologist_clues.has(&"mycologist.trail.notch"):
				return "СЛЕД МИКОЛОГА · принять настой и увидеть скрытое"
			return "НОВЫЙ МАРШРУТ · пройти по северной тропе"


func acknowledge_reward() -> void:
	if stage != Stage.REWARD:
		return
	stage = Stage.DEEP_GROVE
	_emit_state()
	autosave_requested.emit(&"reward_acknowledged")


func record_trail_clue(clue_id: StringName, title: String, text: String) -> void:
	if mycologist_clues.has(clue_id):
		return
	mycologist_clues[clue_id] = true
	narrative_notice_requested.emit(title, text)
	_emit_state()
	autosave_requested.emit(&"mycologist_clue")


func set_spore_vision_active(value: bool) -> void:
	if spore_vision_active == value:
		return
	spore_vision_active = value
	_emit_state()


func set_effect_channels(channels: Dictionary[StringName, float]) -> void:
	spore_vision_active = float(channels.get(&"spore_vision", 0.0)) > 0.1
	spore_quiet_active = float(channels.get(&"spore_resistance", 0.0)) > 0.1
	_emit_state()


func record_grove_entered(_actor: Node = null) -> void:
	if stage != Stage.DEEP_GROVE:
		return
	deep_grove_entered = true
	_emit_state()
	autosave_requested.emit(&"deep_grove_entered")


func record_grove_harvest(item: ItemInstance) -> void:
	if stage != Stage.DEEP_GROVE or item == null:
		return
	if item.definition_id == &"ingredient.emberberry" and item.processing_state.get(&"part", &"") == &"berry":
		emberberry_collected = true
		_emit_state()
		autosave_requested.emit(&"emberberry_collected")


func record_second_return(_actor: Node = null) -> void:
	if stage != Stage.DEEP_GROVE or not deep_grove_entered or not emberberry_collected:
		return
	second_expedition_complete = true
	narrative_notice_requested.emit("ВТОРАЯ ВЫЛАЗКА ЗАВЕРШЕНА", "Карта из лагеря указывает: миколог искал сердце грибницы, а тлеющие ягоды использовал как защиту от её голоса.")
	_emit_state()
	autosave_requested.emit(&"second_expedition_complete")


func to_save_data() -> Dictionary:
	return {
		"stage": int(stage),
		"route_unlocked": route_unlocked,
		"completed_cycles": completed_cycles,
		"mycologist_clues": mycologist_clues.keys().map(func(value: Variant) -> String: return String(value)),
		"deep_grove_entered": deep_grove_entered,
		"emberberry_collected": emberberry_collected,
		"second_expedition_complete": second_expedition_complete,
		"counteragent_brewed": counteragent_brewed,
	}


func apply_save_data(data: Dictionary) -> void:
	stage = clampi(int(data.get("stage", Stage.EXPEDITION)), Stage.EXPEDITION, Stage.DEEP_GROVE) as Stage
	route_unlocked = bool(data.get("route_unlocked", false))
	completed_cycles = maxi(0, int(data.get("completed_cycles", 0)))
	mycologist_clues.clear()
	for raw_id: Variant in data.get("mycologist_clues", []):
		mycologist_clues[StringName(raw_id)] = true
	deep_grove_entered = bool(data.get("deep_grove_entered", false))
	emberberry_collected = bool(data.get("emberberry_collected", false))
	second_expedition_complete = bool(data.get("second_expedition_complete", false))
	counteragent_brewed = bool(data.get("counteragent_brewed", false))
	route_unlock_changed.emit(route_unlocked)
	_emit_state()


func _on_expedition_returned() -> void:
	if stage != Stage.EXPEDITION:
		return
	stage = Stage.BREW
	_clock.running = false
	_emit_state()
	autosave_requested.emit(&"returned_to_shelter")


func _on_cooking_result(result: RecipeResolution, _display_name: String) -> void:
	if result.result_item_id == &"item.emberberry_tonic" and second_expedition_complete:
		counteragent_brewed = true
		narrative_notice_requested.emit("НОВЫЙ ВЫБОР", "Контрагент почти гасит споровый прилив, но вместе с ним исчезают скрытые тропы. Теперь подготовка определяет доступный маршрут.")
		_emit_state()
		autosave_requested.emit(&"counteragent_brewed")
		return
	if stage != Stage.BREW or result.result_item_id != &"item.spore_sight_brew":
		return
	completed_cycles += 1
	route_unlocked = true
	stage = Stage.REWARD
	var quality_names := ["испорчено", "нестабильно", "рабочее", "чистое", "открытие"]
	var elapsed_seconds := roundi(_clock.progress * _clock.expedition_duration)
	var summary: Dictionary = {
		"title": "ПЕРВАЯ ЦЕПЬ ЗАМКНУТА",
		"quality": quality_names[result.quality],
		"score": roundi(result.score * 100.0),
		"expedition_seconds": elapsed_seconds,
		"knowledge": _knowledge.get_clue_count(&"ingredient.mooncap"),
		"reward": "Открыт проход в глубокую рощу",
	}
	route_unlock_changed.emit(true)
	_emit_state()
	result_ready.emit(summary)
	autosave_requested.emit(&"cycle_completed")


func _emit_state() -> void:
	stage_changed.emit(stage, get_objective_text())
