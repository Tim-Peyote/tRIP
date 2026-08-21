extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var first := _create_scatter()
	var second := _create_scatter()
	first.set_run_seed(77123)
	second.set_run_seed(77123)
	await get_tree().process_frame
	var first_signature := first.get_generation_signature()
	var second_signature := second.get_generation_signature()
	_expect(first_signature == second_signature, "Equal world seeds did not reproduce biome dressing.")
	second.set_run_seed(99117)
	await get_tree().process_frame
	var changed_signature := second.get_generation_signature()
	_expect(first_signature != changed_signature, "Different world seeds did not change biome dressing.")
	first.free()
	second.free()
	_finish()


func _create_scatter() -> BiomeDressingScatter:
	var scatter := BiomeDressingScatter.new()
	scatter.conifer_count = 3
	scatter.broadleaf_count = 2
	scatter.snag_count = 1
	scatter.rock_count = 3
	scatter.log_count = 1
	scatter.distant_ridge_count = 0
	scatter.terrain_mound_count = 0
	add_child(scatter)
	return scatter


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip biome generation test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip biome generation test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
