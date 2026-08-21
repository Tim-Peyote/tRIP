extends Node

var _failures := PackedStringArray()
var _result_quality: int = -1


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	InputBootstrap.ensure_defaults()
	ContentDB.rebuild()
	var level := (load("res://world/levels/shelter/shelter_level.tscn") as PackedScene).instantiate() as ShelterLevel
	add_child(level)
	await get_tree().process_frame
	level.expedition_clock.running = false
	var player := level.player
	var cooking := level.cooking_orchestrator
	cooking.result_created.connect(func(result: RecipeResolution, _name: String) -> void:
		_result_quality = result.quality
	)

	_add_clean_cap(player)
	_expect(_grind_cap(cooking, player), "Clean cap could not be ground.")
	_expect(cooking.add_water(), "Water could not be added.")
	_expect(cooking.transfer_prepared_ingredient(), "Ground cap could not be transferred.")
	cooking.cycle_heat()
	cooking.flip_hourglass()
	while cooking.vessel.temperature < 50.0:
		cooking.vessel.simulate(0.1)
	cooking.stir_vessel()
	cooking.stir_vessel()
	var safety := 0
	while not cooking.vessel.is_ready() and safety < 400:
		cooking.vessel.simulate(0.1)
		safety += 1
	while cooking.vessel.hourglass_running and safety < 500:
		cooking.vessel.simulate(0.1)
		safety += 1
	_expect(cooking.vessel.is_ready(), "Low heat never reached a valid ready state.")
	_expect(not cooking.vessel.is_ruined(), "Low heat ruined a correctly managed brew.")
	_expect(cooking.bottle_result(player), "Ready brew could not be bottled.")
	_expect(_result_quality == RecipeResolution.Quality.PURE, "Managed physical brew was not PURE.")
	_expect(player.inventory.count(&"item.spore_sight_brew") >= 1.0, "Physical cooking did not create a brew item.")

	while player.inventory.count(&"item.spore_sight_brew") > 0.0:
		player.inventory.remove_one(&"item.spore_sight_brew")
	_add_clean_cap(player)
	_expect(_grind_cap(cooking, player), "Second cap could not be ground.")
	cooking.add_water()
	cooking.transfer_prepared_ingredient()
	cooking.cycle_heat()
	cooking.cycle_heat()
	cooking.stir_vessel()
	cooking.stir_vessel()
	safety = 0
	while not cooking.vessel.is_ruined() and safety < 400:
		cooking.vessel.simulate(0.1)
		safety += 1
	_expect(cooking.vessel.is_ruined(), "High heat did not produce an overheat failure.")
	_result_quality = -1
	cooking.bottle_result(player)
	_expect(_result_quality == -1, "Ruined mixture created a valid result.")
	_expect(player.inventory.count(&"item.spore_sight_brew") == 0.0, "Ruined mixture entered inventory.")
	level.free()
	_finish()


func _add_clean_cap(player: FirstPersonController) -> void:
	var cap := ItemInstance.new(&"ingredient.mooncap")
	cap.quality = 1.0
	cap.processing_state[&"part"] = &"cap"
	player.inventory.add_item(cap)


func _grind_cap(cooking: CookingOrchestrator, player: FirstPersonController) -> bool:
	var tags: Array[StringName] = [&"fungus", &"perception"]
	return cooking.perform_action(player, &"grind", &"ingredient.mooncap", tags, 1.0, 20.0, 8.0, &"ingredient.mooncap")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip physical cooking test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip physical cooking test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
