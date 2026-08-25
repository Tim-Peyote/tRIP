extends Node

var _failures: Array[String] = []


func _ready() -> void:
	var level := (load("res://world/levels/shelter/shelter_level.tscn") as PackedScene).instantiate() as ShelterLevel
	add_child(level)
	await get_tree().process_frame
	var map := level.get_map_exploration()
	_expect(not map.get_explored_cells().is_empty(), "Starting area was not revealed.")
	var ordinary_count := map.get_explored_cells(&"phase.ordinary").size()
	level.world_phase_orchestrator.set_developer_phase(&"phase.glass_frost")
	map.call("_reveal_around_player")
	_expect(not map.get_explored_cells(&"phase.glass_frost").is_empty(), "Altered phase did not receive independent exploration.")
	_expect(map.get_explored_cells(&"phase.ordinary").size() == ordinary_count, "Exploring an altered phase changed ordinary-world discovery.")
	var saved := map.to_save_data()
	map.apply_save_data({})
	map.apply_save_data(saved)
	_expect(map.get_explored_cells(&"phase.ordinary").size() == ordinary_count, "Exploration did not survive serialization.")
	if _failures.is_empty():
		print("TRip map exploration test: PASS")
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		print("TRip map exploration test: FAIL (%d)" % _failures.size())
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
