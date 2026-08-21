extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	InputBootstrap.ensure_defaults()
	ContentDB.rebuild()
	var level := (load("res://world/levels/shelter/shelter_level.tscn") as PackedScene).instantiate() as ShelterLevel
	add_child(level)
	level.expedition_clock.running = false
	var loop := level.game_loop_orchestrator
	loop.stage = GameLoopOrchestrator.Stage.DEEP_GROVE
	loop.counteragent_brewed = true
	loop.record_trail_clue(&"mycologist.ring.surge_trace", "Координаты", "Колодец найден.")
	_expect(loop.select_root_well_plan(&"warded_descent"), "Valid warded plan was rejected.")
	_expect(level.root_well.warded_route.visible, "Warded route did not become visible.")
	_expect(not level.root_well.resonant_route.visible, "Resonant route remained active for warded plan.")
	var ward_body := level.root_well.warded_route.get_node("RampA") as StaticBody3D
	var resonance_body := level.root_well.resonant_route.get_node("LongRampA") as StaticBody3D
	_expect(ward_body.collision_layer == 1 and resonance_body.collision_layer == 0, "Route collision did not follow selected plan.")
	level.player.global_position = level.root_well.to_global(Vector3(-3, -1.2, 4.1))
	level.root_well.pressure.force_state(RootPressureOrchestrator.State.HUNTING)
	level.root_well.pressure.pressure = 0.5
	level.root_well.pressure.call("_process", 1.0)
	_expect(level.root_well.pressure.pressure < 0.5, "Physical root membrane did not reduce hunting pressure.")
	level.player.global_position = level.root_well.to_global(Vector3(3, -1.0, 7))
	level.root_well.pressure.pressure = 0.2
	level.root_well.pressure.call("_process", 1.0)
	_expect(level.root_well.pressure.pressure > 0.2, "Open route did not accumulate hunting pressure.")
	loop.record_root_well_entered(level.player)
	_expect(not loop.select_root_well_plan(&"resonant_descent"), "Plan changed after the descent had begun.")
	level.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip root well test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip root well test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
