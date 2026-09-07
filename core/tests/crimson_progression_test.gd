extends Node

const TEST_SLOT: int = 97
var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveService.delete_slot(TEST_SLOT)
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	main.session_scene = load("res://core/tests/fixtures/legacy_expedition_fixture.tscn") as PackedScene
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", TEST_SLOT, true)
	await get_tree().process_frame
	var level := main.find_child("LegacyExpeditionFixture", true, false) as LegacyExpeditionFixture
	var player := level.player
	var blood_antler := level.forest_trail.get_node("SporeRoute/BloodAntler") as PhaseBoundHarvestable
	_expect(not blood_antler.is_phase_available(), "Blood antler was available before entering the mycelial world.")
	main.effect_orchestrator.apply_effects([&"effect.spore_sight"])
	_expect(blood_antler.is_phase_available(), "Spore sight did not reveal the phase-bound ingredient.")
	_expect(blood_antler.collision_layer == 4, "Revealed blood antler remained non-interactive.")
	var sample := ItemInstance.new(&"ingredient.blood_antler", 1.0)
	sample.quality = 1.0
	sample.processing_state[&"part"] = &"cap"
	player.inventory.add_item(sample)
	var tags: Array[StringName] = [&"fungus", &"marrow", &"crimson_drive", &"predator_scent"]
	var ground := level.cooking_orchestrator.perform_action(
		player, &"grind", &"ingredient.blood_antler", tags, 1.0, 20.0, 8.0, &"ingredient.blood_antler"
	)
	var heated := level.cooking_orchestrator.perform_action(
		player, &"heat", &"ingredient.blood_antler", tags, 1.0, 82.0, 24.0
	)
	_expect(ground and heated, "Crimson formula rejected its correct operation sequence.")
	_expect(player.inventory.count(&"item.crimson_marrow_stew") == 1.0, "Correct crimson formula did not create the world key.")
	_expect(level.recipe_knowledge_orchestrator.is_learned(&"recipe.crimson_marrow_stew"), "Successful formula was not retained as recipe knowledge.")
	var base_speed := player.walk_speed
	var base_exposure := player.get_stealth_exposure()
	_expect(player.inventory.use_first_consumable(), "Crimson world key could not be consumed.")
	await get_tree().process_frame
	_expect(main.effect_orchestrator.has_effect(&"effect.crimson_drive"), "Crimson drive effect did not start.")
	_expect(not main.effect_orchestrator.has_effect(&"effect.spore_sight"), "Crimson brew did not replace the previous consciousness layer.")
	_expect(level.world_phase_orchestrator.get_current().id == &"phase.crimson_hunt", "Correct brew did not move generation into Crimson Hunt.")
	_expect(float(player.call("_get_target_speed")) > base_speed, "Crimson Hunt granted no movement opportunity.")
	_expect(player.get_stealth_exposure() > base_exposure, "Crimson Hunt imposed no creature-attraction price.")
	var save_data := level.session_persistence.capture_save_data()
	var recipe_data := save_data.get("recipe_knowledge", {}) as Dictionary
	_expect("recipe.crimson_marrow_stew" in recipe_data.get("learned", []), "Learned crimson formula was absent from persistence data.")
	main.queue_free()
	await get_tree().process_frame
	SaveService.delete_slot(TEST_SLOT)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip crimson progression test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip crimson progression test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
