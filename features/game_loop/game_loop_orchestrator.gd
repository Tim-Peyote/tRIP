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


func to_save_data() -> Dictionary:
	return {
		"stage": int(stage),
		"route_unlocked": route_unlocked,
		"completed_cycles": completed_cycles,
		"mycologist_clues": mycologist_clues.keys().map(func(value: Variant) -> String: return String(value)),
	}


func apply_save_data(data: Dictionary) -> void:
	stage = clampi(int(data.get("stage", Stage.EXPEDITION)), Stage.EXPEDITION, Stage.DEEP_GROVE) as Stage
	route_unlocked = bool(data.get("route_unlocked", false))
	completed_cycles = maxi(0, int(data.get("completed_cycles", 0)))
	mycologist_clues.clear()
	for raw_id: Variant in data.get("mycologist_clues", []):
		mycologist_clues[StringName(raw_id)] = true
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
