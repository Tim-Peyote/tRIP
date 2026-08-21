extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _validate_landscape_rules()
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


func _validate_landscape_rules() -> void:
	var terrain := ExpeditionTerrain.new()
	add_child(terrain)
	await get_tree().process_frame
	var clearing_height := terrain.get_height_at_global(Vector3(0, 0, 15))
	var trail_height := terrain.get_height_at_global(Vector3(0, 0, 35))
	var camp_height := terrain.get_height_at_global(Vector3(31.5, 0, 20.5))
	var ramp_height := terrain.get_height_at_global(Vector3(25, 0, 18.5))
	_expect(absf(clearing_height) < 0.08, "The shelter clearing is not authored as a stable landing area.")
	_expect(trail_height > -0.1 and trail_height < 0.35, "The expedition trail left its authored height corridor.")
	_expect(camp_height > 1.45, "The deep-grove camp landmark lost its natural elevation.")
	_expect(ramp_height > clearing_height and ramp_height < camp_height, "The camp approach is not a continuous slope.")
	_expect(terrain.get_loaded_chunk_count() >= 1, "Streaming terrain did not create its center chunk.")
	var target := Node3D.new()
	add_child(target)
	target.global_position = Vector3(95, 0, 95)
	terrain.setup(target)
	for _frame in 4:
		await get_tree().process_frame
	_expect(terrain.get_loaded_chunk_count() >= 4, "Streaming terrain did not page chunks around a moving player.")
	terrain.set_world_phase(ExpeditionTerrain.PHASE_MYCELIAL)
	_expect(terrain.get_world_phase() == ExpeditionTerrain.PHASE_MYCELIAL, "Consumable world phase was not applied to terrain generation.")
	target.free()
	terrain.free()


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
