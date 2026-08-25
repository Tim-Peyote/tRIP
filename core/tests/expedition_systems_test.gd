extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	InputBootstrap.ensure_defaults()
	ContentDB.rebuild()
	var level := (load("res://world/levels/shelter/shelter_level.tscn") as PackedScene).instantiate() as ShelterLevel
	add_child(level)
	await get_tree().process_frame
	var player := level.get_player()
	var forest := level.get_node("ForestClearing") as ForestClearingChunk
	var false_mooncap := forest.get_node("FalseMooncap") as HarvestableIngredient
	false_mooncap.interactable.request_inspection(player)
	_expect(level.knowledge_orchestrator.get_level(&"ingredient.false_mooncap") == KnowledgeOrchestrator.Level.OBSERVED, "Inspection did not update herbarium knowledge.")

	player.toolbelt.cycle_active_tool()
	_expect(player.toolbelt.active_tool_id == &"tool.spore_vial", "Toolbelt did not cycle to the spore vial.")
	for _index in 3:
		false_mooncap.interactable.request_alternative(player)
	_expect(false_mooncap.get_selected_part() == &"spores", "Harvest part did not cycle to spores.")
	_expect(false_mooncap.interactable.can_interact(player), "Spore vial cannot collect spores.")

	var wrong_sample := ItemInstance.new(&"ingredient.false_mooncap")
	wrong_sample.processing_state[&"part"] = &"cap"
	level.objective_orchestrator.record_harvest(wrong_sample)
	_expect(level.objective_orchestrator.stage == ExpeditionObjectiveOrchestrator.Stage.SEEK_MOONCAP, "False mooncap advanced the expedition objective.")
	var correct_sample := ItemInstance.new(&"ingredient.mooncap")
	correct_sample.processing_state[&"part"] = &"cap"
	level.objective_orchestrator.record_harvest(correct_sample)
	_expect(level.objective_orchestrator.stage == ExpeditionObjectiveOrchestrator.Stage.RETURN_TO_SHELTER, "Correct cap did not unlock the return objective.")
	level.objective_orchestrator.record_return(player)
	_expect(level.objective_orchestrator.stage == ExpeditionObjectiveOrchestrator.Stage.COMPLETE, "Returning did not complete the expedition.")

	level.expedition_clock.running = false
	level.expedition_clock.set_progress(0.65)
	_expect(level.expedition_clock.phase == ExpeditionClock.Phase.DUSK, "Clock did not enter dusk.")
	level.expedition_clock.set_progress(0.8)
	_expect(level.expedition_clock.phase == ExpeditionClock.Phase.NIGHT, "Clock did not enter night.")
	_expect(is_equal_approx(level.expedition_clock.get_daylight_duration(), 1260.0), "Daylight does not use the 21-minute pacing target.")
	_expect(is_equal_approx(level.expedition_clock.get_night_duration(), 540.0), "Night does not use the 9-minute pacing target.")
	level.expedition_clock.set_progress(0.99)
	var day_before_wrap := level.expedition_clock.day_index
	level.expedition_clock.advance(30.0)
	_expect(level.expedition_clock.day_index == day_before_wrap + 1 and level.expedition_clock.progress < 0.04, "Clock did not wrap into the next dawn.")
	_expect(level.expedition_clock.get_elapsed_seconds() >= 30.0, "Expedition elapsed time was lost when the day wrapped.")

	var event := GameplayNoiseEvent.new()
	event.origin = forest.listener.global_position + Vector3(1, 0, 0)
	event.radius = 4.0
	event.intensity = 1.0
	event.tag = &"test_noise"
	forest.listener.hear_noise(event)
	_expect(forest.listener.state == ListenerCreature.State.ALERT, "Listener did not react to a loud nearby noise.")
	level.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip expedition systems test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip expedition systems test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
