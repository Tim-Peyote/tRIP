class_name KnowledgeOrchestrator
extends Node

signal entry_changed(definition_id: StringName, level: int)
signal clue_recorded(definition_id: StringName, clue_id: StringName, discovered: int, total: int)

enum Level { UNKNOWN, OBSERVED, COLLECTED, UNDERSTOOD }

var _levels: Dictionary[StringName, int] = {}
var _clues: Dictionary[StringName, Dictionary] = {}
var _clue_totals: Dictionary[StringName, int] = {}


func observe(definition_id: StringName) -> void:
	_advance(definition_id, Level.OBSERVED)


func record_harvest(item: ItemInstance) -> void:
	if item != null:
		_advance(item.definition_id, Level.COLLECTED)


func understand(definition_id: StringName) -> void:
	_advance(definition_id, Level.UNDERSTOOD)


func record_clue(definition_id: StringName, clue_id: StringName, total_clues: int) -> void:
	observe(definition_id)
	if not _clues.has(definition_id):
		_clues[definition_id] = {}
	var entries: Dictionary = _clues[definition_id]
	if entries.has(clue_id):
		return
	entries[clue_id] = true
	_clue_totals[definition_id] = maxi(total_clues, int(_clue_totals.get(definition_id, 0)))
	clue_recorded.emit(definition_id, clue_id, entries.size(), total_clues)
	if total_clues > 0 and entries.size() >= total_clues:
		understand(definition_id)


func has_clue(clue_id: StringName) -> bool:
	for definition_id: StringName in _clues:
		if (_clues[definition_id] as Dictionary).has(clue_id):
			return true
	return false


func get_clue_count(definition_id: StringName) -> int:
	return (_clues.get(definition_id, {}) as Dictionary).size()


func get_level(definition_id: StringName) -> int:
	return int(_levels.get(definition_id, Level.UNKNOWN))


func get_display_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var ids: Array = _levels.keys()
	ids.sort()
	var level_names := ["неизвестно", "осмотрено", "образец взят", "изучено"]
	for raw_id: Variant in ids:
		var definition_id := StringName(raw_id)
		var definition := ContentDB.get_definition(definition_id)
		var title := definition.display_name if definition != null else String(definition_id)
		var clue_count := get_clue_count(definition_id)
		var clue_total := int(_clue_totals.get(definition_id, 0))
		var clue_suffix := " · признаки %d/%d" % [clue_count, clue_total] if clue_total > 0 else ""
		lines.append("%s — %s%s" % [title, level_names[get_level(definition_id)], clue_suffix])
	return lines


func _advance(definition_id: StringName, level: int) -> void:
	if definition_id == &"" or level <= get_level(definition_id):
		return
	_levels[definition_id] = level
	entry_changed.emit(definition_id, level)
