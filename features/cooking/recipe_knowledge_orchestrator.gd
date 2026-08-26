class_name RecipeKnowledgeOrchestrator
extends Node

signal recipe_learned(recipe_id: StringName, display_name: String)
signal recipe_observation_added(recipe_id: StringName, message: String)

var _cooking: CookingOrchestrator
var _learned: Dictionary[StringName, bool] = {}
var _discovered: Dictionary[StringName, bool] = {}
var _attempts: Dictionary = {}
var _observations: Dictionary = {}


func setup(cooking: CookingOrchestrator) -> void:
	_cooking = cooking
	if _cooking != null and not _cooking.result_created.is_connected(_on_result_created):
		_cooking.result_created.connect(_on_result_created)
	if _cooking != null and not _cooking.batch_evaluated.is_connected(_on_batch_evaluated):
		_cooking.batch_evaluated.connect(_on_batch_evaluated)


func is_learned(recipe_id: StringName) -> bool:
	return _learned.has(recipe_id)


func is_discovered(recipe_id: StringName) -> bool:
	return _discovered.has(recipe_id) or _learned.has(recipe_id)


func discover_recipe(recipe_id: StringName) -> void:
	if recipe_id == &"" or is_discovered(recipe_id):
		return
	_discovered[recipe_id] = true
	var recipe := _cooking.find_recipe_by_id(recipe_id) if _cooking != null else null
	recipe_learned.emit(recipe_id, "ГИПОТЕЗА · %s" % (recipe.display_name if recipe != null else String(recipe_id)))


func get_learned_recipe_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_learned.keys())
	result.sort()
	return result


func get_display_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if _cooking == null:
		return lines
	var visible_ids: Array[StringName] = []
	visible_ids.assign(_discovered.keys())
	for learned_id: StringName in _learned:
		if learned_id not in visible_ids:
			visible_ids.append(learned_id)
	visible_ids.sort()
	for recipe_id: StringName in visible_ids:
		var recipe := _cooking.find_recipe_by_id(recipe_id)
		if recipe != null:
			var state := "ОСВОЕНО" if _learned.has(recipe_id) else "ГИПОТЕЗА"
			lines.append("%s · %s\n%s" % [state, recipe.display_name, recipe.field_notes])
	return lines


func get_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _cooking == null:
		return result
	var visible_ids: Array[StringName] = []
	visible_ids.assign(_discovered.keys())
	for learned_id: StringName in _learned:
		if learned_id not in visible_ids:
			visible_ids.append(learned_id)
	visible_ids.sort()
	for recipe_id: StringName in visible_ids:
		var recipe := _cooking.find_recipe_by_id(recipe_id)
		if recipe == null:
			continue
		var step_entries: Array[Dictionary] = []
		for step: RecipeStepDefinition in recipe.steps:
			step_entries.append({
				"operation": step.operation,
				"hint": step.player_hint,
				"temperature_min": step.minimum_temperature,
				"temperature_max": step.maximum_temperature,
				"duration_min": step.minimum_duration,
				"duration_max": step.maximum_duration,
				"turns_min": step.minimum_hourglass_turns,
				"turns_max": step.maximum_hourglass_turns,
				"sensory_cue": step.sensory_cue,
			})
		result.append({
			"id": recipe.id,
			"title": recipe.display_name,
			"description": recipe.description,
			"field_notes": recipe.field_notes,
			"learned": _learned.has(recipe_id),
			"primary_ingredient_id": recipe.primary_ingredient_id,
			"result_item_id": recipe.result_item_id,
			"step_count": recipe.steps.size(),
			"steps": step_entries,
			"base_id": recipe.required_base_id,
			"finish_method": recipe.finish_method,
			"station_tier": recipe.minimum_station_tier,
			"base_yield": recipe.base_yield,
			"attempt_count": int(_attempts.get(recipe_id, 0)),
			"observations": (_observations.get(recipe_id, []) as Array).duplicate(),
		})
	return result


func to_save_data() -> Dictionary:
	return {
		"learned": _learned.keys().map(func(value: Variant) -> String: return String(value)),
		"discovered": _discovered.keys().map(func(value: Variant) -> String: return String(value)),
		"attempts": _string_keyed_dictionary(_attempts),
		"observations": _string_keyed_dictionary(_observations),
	}


func apply_save_data(data: Dictionary) -> void:
	_learned.clear()
	_discovered.clear()
	_attempts.clear()
	_observations.clear()
	for raw_id: Variant in data.get("discovered", []):
		_discovered[StringName(raw_id)] = true
	for raw_id: Variant in data.get("learned", []):
		var recipe_id := StringName(raw_id)
		_learned[recipe_id] = true
		var recipe := _cooking.find_recipe_by_id(recipe_id) if _cooking != null else null
		recipe_learned.emit(recipe_id, recipe.display_name if recipe != null else String(recipe_id))
	for raw_id: Variant in (data.get("attempts", {}) as Dictionary):
		_attempts[StringName(raw_id)] = maxi(0, int((data.get("attempts", {}) as Dictionary)[raw_id]))
	for raw_id: Variant in (data.get("observations", {}) as Dictionary):
		var values: Array = (data.get("observations", {}) as Dictionary)[raw_id]
		_observations[StringName(raw_id)] = values.duplicate()


func _on_result_created(_result: RecipeResolution, _display_name: String) -> void:
	if _cooking == null or _cooking.active_recipe == null:
		return
	var recipe_id := _cooking.active_recipe.id
	if _learned.has(recipe_id):
		return
	_learned[recipe_id] = true
	_discovered.erase(recipe_id)
	recipe_learned.emit(recipe_id, _cooking.active_recipe.display_name)


func _on_batch_evaluated(recipe_id: StringName, result: RecipeResolution) -> void:
	if recipe_id == &"":
		return
	_attempts[recipe_id] = int(_attempts.get(recipe_id, 0)) + 1
	if not is_discovered(recipe_id):
		_discovered[recipe_id] = true
	var stored: Array = _observations.get(recipe_id, [])
	var additions := PackedStringArray()
	for tag: StringName in result.explanation_tags:
		var observation := _observation_for_tag(tag)
		if observation != "" and observation not in stored:
			stored.append(observation)
			additions.append(observation)
	_observations[recipe_id] = stored
	if not additions.is_empty():
		recipe_observation_added.emit(recipe_id, additions[0])


func _observation_for_tag(tag: StringName) -> String:
	return {
		&"wrong_operation": "Порядок обработки влияет на связывание состава.",
		&"wrong_ingredient_trait": "Для формулы нужна другая часть или признак образца.",
		&"amount_out_of_range": "Следующая проба требует иной дозировки.",
		&"temperature_out_of_range": "Рабочее температурное окно уже наблюдавшегося диапазона.",
		&"duration_out_of_range": "Выдержку следует изменить.",
		&"insufficient_stirring": "Неоднородность разрушает состав.",
		&"overheated": "При перегреве активная фракция выгорает.",
		&"wrong_base": "Эта основа не извлекает нужные свойства.",
		&"wrong_finish": "Состав требует другого способа завершения.",
		&"station_too_primitive": "Нужны более точные инструменты лаборатории.",
		&"wrong_turn_count": "Песочные часы указывают неверную выдержку.",
		&"damaged_source": "Повреждённое сырьё ухудшает итог.",
		&"step_count_mismatch": "В опыте пропущен или добавлен этап.",
	}.get(tag, "")


func _string_keyed_dictionary(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source:
		var value: Variant = source[key]
		result[String(key)] = value.duplicate() if value is Array or value is Dictionary else value
	return result
