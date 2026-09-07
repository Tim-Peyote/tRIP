extends Node

const TEST_SLOT: int = 99
var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	InputBootstrap.ensure_defaults()
	ContentDB.rebuild()
	SaveService.delete_slot(TEST_SLOT)
	var level := _create_level()
	var persistence := level.session_persistence
	persistence.setup(level, level.game_loop_orchestrator, TEST_SLOT)
	var forest_mooncap := level.forest_clearing.get_node("Mooncap") as HarvestableIngredient
	forest_mooncap.interactable.complete_interaction(level.player)
	await get_tree().process_frame
	_expect(level.objective_orchestrator.stage == ExpeditionObjectiveOrchestrator.Stage.RETURN_TO_SHELTER, "Correct forest harvest did not advance return objective.")
	level.objective_orchestrator.record_return(level.player)
	_expect(level.game_loop_orchestrator.stage == GameLoopOrchestrator.Stage.BREW, "Return did not advance loop to brewing.")
	level.knowledge_orchestrator.record_clue(&"ingredient.mooncap", &"observation.mooncap.silver_veins", 3)
	var tags: Array[StringName] = [&"fungus", &"perception"]
	level.cooking_orchestrator.perform_action(level.player, &"grind", &"ingredient.mooncap", tags, 1.0, 20.0, 8.0, &"ingredient.mooncap")
	level.cooking_orchestrator.perform_action(level.player, &"heat", &"ingredient.mooncap", tags, 1.0, 80.0, 24.0)
	_expect(level.game_loop_orchestrator.stage == GameLoopOrchestrator.Stage.REWARD, "Pure brew did not complete the first cycle.")
	_expect(not level.deep_grove_gate.locked, "Cycle reward did not unlock deep grove gate.")
	level.game_loop_orchestrator.acknowledge_reward()
	var first_clue := level.forest_trail.get_node("ClueFirst")
	(first_clue.get_node("InteractableComponent") as InteractableComponent).complete_interaction(level.player)
	_expect(level.game_loop_orchestrator.mycologist_clues.has(&"mycologist.trail.notch"), "Mycologist trail clue did not advance narrative progress.")
	level.apply_gameplay_channels({&"spore_vision": 1.0})
	_expect(not (level.forest_trail.get_node("SporeRoute/VisionGate") as SimplePortal).locked, "Spore sight did not reveal the hidden route.")
	var hidden_clue := level.forest_trail.get_node("ClueHidden")
	(hidden_clue.get_node("InteractableComponent") as InteractableComponent).complete_interaction(level.player)
	_expect(level.game_loop_orchestrator.mycologist_clues.has(&"mycologist.trail.spore_message"), "Hidden mycologist message was not recorded.")
	var vision_gate := level.forest_trail.get_node("SporeRoute/VisionGate") as SimplePortal
	(vision_gate.get_node("InteractableComponent") as InteractableComponent).complete_interaction(level.player)
	_expect(level.game_loop_orchestrator.deep_grove_entered, "Entering the revealed route did not begin the second expedition.")
	var camp_clue := level.deep_grove.get_node("MycologistCamp/CampClue")
	(camp_clue.get_node("InteractableComponent") as InteractableComponent).complete_interaction(level.player)
	_expect(level.game_loop_orchestrator.mycologist_clues.has(&"mycologist.camp.abandoned"), "Mycologist camp clue was not recorded.")
	var emberberry := level.deep_grove.get_node("EmberberryA") as HarvestableIngredient
	emberberry.interactable.complete_interaction(level.player)
	_expect(level.game_loop_orchestrator.emberberry_collected, "Emberberry harvest did not advance the second expedition.")
	level.game_loop_orchestrator.record_second_return(level.player)
	_expect(level.game_loop_orchestrator.second_expedition_complete, "Returning with emberberry did not complete the second expedition.")
	var berry_tags: Array[StringName] = [&"berry", &"warming", &"counteragent"]
	level.cooking_orchestrator.perform_action(level.player, &"grind", &"ingredient.emberberry", berry_tags, 1.0, 20.0, 8.0, &"ingredient.emberberry")
	level.cooking_orchestrator.perform_action(level.player, &"heat", &"ingredient.emberberry", berry_tags, 1.0, 80.0, 24.0)
	_expect(level.game_loop_orchestrator.counteragent_brewed, "Brewing emberberry tonic did not unlock the preparation choice.")
	_expect(not level.game_loop_orchestrator.select_root_well_plan(&"warded_descent"), "Root-well plan was selectable before discovering the surge trace.")
	level.game_loop_orchestrator.record_trail_clue(&"mycologist.ring.surge_trace", "Координаты", "Колодец под кольцом.")
	var board := level.get_investigation_board()
	(board.get_node("InteractableComponent") as InteractableComponent).complete_interaction(level.player)
	_expect(level.game_loop_orchestrator.root_well_plan == &"warded_descent", "Investigation board did not select the warded descent plan.")
	_expect("ТИХАЯ КРОВЬ" in level.game_loop_orchestrator.get_objective_text(), "Selected board plan did not change the objective.")
	_expect(not level.root_well_gate.locked, "Selected expedition plan did not unlock the ancient-ring entrance.")
	level.game_loop_orchestrator.record_root_well_entered(level.player)
	var voice_clue := level.root_well.get_node("MycologistSignal")
	(voice_clue.get_node("InteractableComponent") as InteractableComponent).complete_interaction(level.player)
	_expect(level.game_loop_orchestrator.mycologist_clues.has(&"mycologist.well.voice"), "Mycologist voice in the root well was not recorded.")
	level.game_loop_orchestrator.initialize_world_seed(424242)
	level.apply_world_seed(level.game_loop_orchestrator.world_seed)
	level.player.global_position = Vector3(20.5, 0.12, 15.0)
	persistence.save_now(&"test_complete")
	_expect(SaveService.has_save(TEST_SLOT), "Session save file was not created.")
	level.free()

	var loaded_level := _create_level()
	var loaded_persistence := loaded_level.session_persistence
	loaded_persistence.setup(loaded_level, loaded_level.game_loop_orchestrator, TEST_SLOT)
	_expect(loaded_persistence.load(), "Saved session could not be loaded.")
	await get_tree().process_frame
	_expect(loaded_level.game_loop_orchestrator.stage == GameLoopOrchestrator.Stage.DEEP_GROVE, "Game loop stage was not restored.")
	_expect(not loaded_level.deep_grove_gate.locked, "Unlocked route was not restored.")
	_expect(loaded_level.game_loop_orchestrator.mycologist_clues.has(&"mycologist.trail.spore_message"), "Mycologist narrative progress was not restored.")
	_expect(loaded_level.game_loop_orchestrator.mycologist_clues.has(&"mycologist.camp.abandoned"), "Mycologist camp progress was not restored.")
	_expect(loaded_level.game_loop_orchestrator.second_expedition_complete, "Second expedition completion was not restored.")
	_expect(loaded_level.player.inventory.count(&"item.emberberry_tonic") == 1.0, "Emberberry counteragent was not restored.")
	_expect(loaded_level.game_loop_orchestrator.counteragent_brewed, "Counteragent progression was not restored.")
	_expect(loaded_level.game_loop_orchestrator.root_well_plan == &"warded_descent", "Root-well preparation plan was not restored.")
	_expect(loaded_level.game_loop_orchestrator.root_well_entered, "Root-well entry state was not restored.")
	_expect(loaded_level.game_loop_orchestrator.mycologist_clues.has(&"mycologist.well.voice"), "Root-well narrative signal was not restored.")
	_expect(loaded_level.game_loop_orchestrator.world_seed == 424242, "Procedural biome seed was not restored.")
	_expect(loaded_level.investigation_board.warded_marker.visible, "Physical investigation board did not restore its selected marker.")
	_expect(loaded_level.knowledge_orchestrator.has_clue(&"observation.mooncap.silver_veins"), "Knowledge clue was not restored.")
	_expect(loaded_level.player.inventory.count(&"item.spore_sight_brew") == 1.0, "Inventory item was not restored.")
	_expect(loaded_level.forest_clearing.get_node_or_null("Mooncap") == null, "Harvested world spawn returned after loading.")
	_expect(loaded_level.player.global_position.distance_to(Vector3(20.5, 0.12, 15.0)) < 0.1, "Player position was not restored.")
	loaded_level.free()
	SaveService.delete_slot(TEST_SLOT)
	_finish()


func _create_level() -> LegacyExpeditionFixture:
	var level := (load("res://core/tests/fixtures/legacy_expedition_fixture.tscn") as PackedScene).instantiate() as LegacyExpeditionFixture
	add_child(level)
	level.expedition_clock.running = false
	return level


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip full cycle/persistence test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip full cycle/persistence test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
