class_name RecipeKnowledgeOrchestrator
extends Node

signal recipe_learned(recipe_id: StringName, display_name: String)

var _cooking: CookingOrchestrator
var _learned: Dictionary[StringName, bool] = {}
var _discovered: Dictionary[StringName, bool] = {}


func setup(cooking: CookingOrchestrator) -> void:
	_cooking = cooking
	if _cooking != null and not _cooking.result_created.is_connected(_on_result_created):
		_cooking.result_created.connect(_on_result_created)


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


func to_save_data() -> Dictionary:
	return {
		"learned": _learned.keys().map(func(value: Variant) -> String: return String(value)),
		"discovered": _discovered.keys().map(func(value: Variant) -> String: return String(value)),
	}


func apply_save_data(data: Dictionary) -> void:
	_learned.clear()
	_discovered.clear()
	for raw_id: Variant in data.get("discovered", []):
		_discovered[StringName(raw_id)] = true
	for raw_id: Variant in data.get("learned", []):
		var recipe_id := StringName(raw_id)
		_learned[recipe_id] = true
		var recipe := _cooking.find_recipe_by_id(recipe_id) if _cooking != null else null
		recipe_learned.emit(recipe_id, recipe.display_name if recipe != null else String(recipe_id))


func _on_result_created(_result: RecipeResolution, _display_name: String) -> void:
	if _cooking == null or _cooking.active_recipe == null:
		return
	var recipe_id := _cooking.active_recipe.id
	if _learned.has(recipe_id):
		return
	_learned[recipe_id] = true
	_discovered.erase(recipe_id)
	recipe_learned.emit(recipe_id, _cooking.active_recipe.display_name)
