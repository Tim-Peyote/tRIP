extends Node

const TEST_SLOT: int = 98
var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	InputBootstrap.ensure_defaults()
	ContentDB.rebuild()
	SaveService.delete_slot(TEST_SLOT)
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", TEST_SLOT, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	var player := level.player
	var berry := ItemInstance.new(&"ingredient.emberberry", 1.0)
	berry.quality = 1.0
	berry.processing_state[&"part"] = &"berry"
	player.inventory.add_item(berry)
	var tags: Array[StringName] = [&"berry", &"warming", &"counteragent"]
	level.cooking_orchestrator.perform_action(player, &"grind", &"ingredient.emberberry", tags, 1.0, 20.0, 8.0, &"ingredient.emberberry")
	level.cooking_orchestrator.perform_action(player, &"heat", &"ingredient.emberberry", tags, 1.0, 80.0, 24.0)
	_expect(player.inventory.count(&"item.emberberry_tonic") == 1.0, "Emberberry recipe did not create counteragent.")
	main.effect_orchestrator.apply_effects([&"effect.spore_sight"])
	_expect(main.effect_orchestrator.has_effect(&"effect.spore_sight"), "Spore sight did not start.")
	main.effect_orchestrator.apply_effects([&"effect.spore_quiet"])
	_expect(not main.effect_orchestrator.has_effect(&"effect.spore_sight"), "Counteragent did not cancel spore sight.")
	_expect(main.effect_orchestrator.has_effect(&"effect.spore_quiet"), "Counteragent effect did not start.")
	_expect(level.forest_trail.get_node("SporeRoute").visible == false, "Hidden route remained visible under counteragent.")
	player.global_position = Vector3(25, 0.12, 15)
	level.spore_tide.force_state(SporeTideOrchestrator.State.SURGE)
	level.spore_tide.exposure = 0.0
	level.spore_tide._process(5.0)
	_expect(level.spore_tide.exposure < 0.1, "Counteragent did not resist spore tide exposure.")
	main.effect_orchestrator.clear()
	level.spore_tide.exposure = 0.0
	level.spore_tide.force_state(SporeTideOrchestrator.State.SURGE)
	level.spore_tide._process(5.0)
	_expect(level.spore_tide.exposure > 0.35, "Unprotected spore tide did not create meaningful exposure.")
	player.global_position = Vector3(18.2, 0.12, 9.8)
	level.spore_tide.exposure = 0.5
	level.spore_tide.force_state(SporeTideOrchestrator.State.SURGE)
	level.spore_tide._process(3.0)
	_expect(level.spore_tide.exposure < 0.5, "Physical spore shelter did not drain exposure during surge.")
	var surge_clue := level.deep_grove.get_node("SurgeClue")
	_expect(not surge_clue.visible, "Surge clue was visible without spore sight.")
	main.effect_orchestrator.apply_effects([&"effect.spore_sight"])
	_expect(surge_clue.visible, "Surge clue did not appear when tide and spore sight aligned.")
	(surge_clue.get_node("InteractableComponent") as InteractableComponent).complete_interaction(player)
	_expect(level.game_loop_orchestrator.mycologist_clues.has(&"mycologist.ring.surge_trace"), "Risk-route mycologist clue was not recorded.")
	main.queue_free()
	await get_tree().process_frame
	SaveService.delete_slot(TEST_SLOT)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip counteragent/tide test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip counteragent/tide test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
