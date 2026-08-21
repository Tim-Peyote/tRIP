extends Node

const TEST_SLOT := 89
var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	SaveService.delete_slot(TEST_SLOT)
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", TEST_SLOT, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	var terrain := level.get_node("ExpeditionTerrain") as ExpeditionTerrain
	var phase_ids: Array[StringName] = [
		&"phase.ordinary", &"phase.mycelial_choir", &"phase.crimson_hunt", &"phase.glass_frost",
		&"phase.ashen_silence", &"phase.mirror_flood", &"phase.root_dream", &"phase.distant_heart",
	]
	var expected_ingredients: Array[StringName] = [
		&"ingredient.mooncap", &"ingredient.blood_antler", &"ingredient.glass_lichen", &"ingredient.ashen_bell",
		&"ingredient.mirror_reed", &"ingredient.deep_root", &"ingredient.concordance_cap",
	]
	for index: int in phase_ids.size():
		var phase := level.world_phase_orchestrator.get_current()
		_expect(phase.id == phase_ids[index], "World chain entered an unexpected phase at index %d." % index)
		var pack := phase.content_pack
		_expect(pack != null and not pack.mysteries.is_empty(), "World %s has no authored mystery." % phase.id)
		var probe_body := StaticBody3D.new()
		terrain.add_child(probe_body)
		var probe_rng := RandomNumberGenerator.new()
		probe_rng.seed = 700 + index
		terrain.call("_add_point_of_interest", probe_body, Vector2i(20 + index, 20), probe_rng)
		_expect(not probe_body.find_children("*", "WorldMysteryPOI", true, false).is_empty(), "World %s generated no interactive POI." % phase.id)
		if index >= expected_ingredients.size():
			probe_body.free()
			break
		var generated_samples := probe_body.find_children("*", "GeneratedBiomeIngredient", true, false)
		_expect(not generated_samples.is_empty(), "World %s generated no local ingredient near its POI." % phase.id)
		if not generated_samples.is_empty():
			_expect((generated_samples[0] as GeneratedBiomeIngredient).definition_id == expected_ingredients[index], "Generated POI sample does not belong to world %s." % phase.id)
			if index == 2:
				var generated_sample := generated_samples[0] as GeneratedBiomeIngredient
				var generated_interactable := generated_sample.find_children("*", "InteractableComponent", true, false)[0] as InteractableComponent
				generated_interactable.complete_interaction(level.player)
				_expect(terrain.get_collected_biome_ingredient_spawns().has(generated_sample.spawn_id), "Generated local sample collection was not recorded.")
				level.player.inventory.remove_one(expected_ingredients[index])
		probe_body.free()
		_expect(pack.local_ingredient_ids.has(expected_ingredients[index]), "World %s exposes the wrong local ingredient." % phase.id)
		var mystery := pack.mysteries[0]
		terrain.mystery_discovered.emit(mystery)
		_expect(level.get_world_progression().has_discovered(mystery.id), "Mystery %s was not recorded." % mystery.id)
		_expect(level.recipe_knowledge_orchestrator.is_discovered(pack.transition_recipe_id), "Mystery did not reveal transition recipe %s." % pack.transition_recipe_id)
		var recipe := level.cooking_orchestrator.find_recipe_by_id(pack.transition_recipe_id)
		_expect(recipe != null, "Transition recipe %s is not registered at the laboratory." % pack.transition_recipe_id)
		if recipe == null:
			continue
		var ingredient := ContentDB.get_definition(recipe.primary_ingredient_id) as IngredientDefinition
		_expect(ingredient != null, "Recipe %s has no local ingredient content." % recipe.id)
		var sample := ItemInstance.new(recipe.primary_ingredient_id, 1.0)
		sample.quality = 1.0
		sample.processing_state[&"part"] = &"cap" if index < 2 else &"whole"
		level.player.inventory.add_item(sample)
		var tags := ingredient.tags.duplicate()
		var first := recipe.steps[0]
		var second := recipe.steps[1]
		var ground_ok := level.cooking_orchestrator.perform_action(
			level.player, first.operation, recipe.primary_ingredient_id, tags, 1.0,
			(first.minimum_temperature + first.maximum_temperature) * 0.5,
			(first.minimum_duration + first.maximum_duration) * 0.5,
			recipe.primary_ingredient_id
		)
		var heat_ok := level.cooking_orchestrator.perform_action(
			level.player, second.operation, recipe.primary_ingredient_id, tags, 1.0,
			(second.minimum_temperature + second.maximum_temperature) * 0.5,
			(second.minimum_duration + second.maximum_duration) * 0.5
		)
		_expect(ground_ok and heat_ok, "Correct transition formula %s was rejected." % recipe.id)
		_expect(level.recipe_knowledge_orchestrator.is_learned(recipe.id), "Successful transition formula %s was not learned." % recipe.id)
		_expect(level.player.inventory.use_first_consumable(), "Transition result for %s could not be consumed." % recipe.id)
		await get_tree().process_frame
		_expect(level.world_phase_orchestrator.get_current().id == phase_ids[index + 1], "Consuming %s did not rebuild the world into %s." % [recipe.id, phase_ids[index + 1]])
	var save_data := level.session_persistence.capture_save_data()
	var progression_data := save_data.get("world_progression", {}) as Dictionary
	_expect((progression_data.get("discovered_mysteries", []) as Array).size() == 7, "World mysteries were not persisted across the full chain.")
	_expect((progression_data.get("collected_biome_ingredients", []) as Array).size() == 1, "Collected procedural ingredient spawn was not persisted.")
	_expect(StringName(progression_data.get("story_phase_id", "")) == &"phase.distant_heart", "Highest reached story world was not persisted.")
	main.effect_orchestrator.clear()
	await get_tree().process_frame
	_expect(level.world_phase_orchestrator.get_current().id == &"phase.distant_heart", "Final story world collapsed when the acute consumable effect ended.")
	var restored := (load("res://world/levels/shelter/shelter_level.tscn") as PackedScene).instantiate() as ShelterLevel
	add_child(restored)
	restored.expedition_clock.running = false
	restored.session_persistence.setup(restored, restored.game_loop_orchestrator, TEST_SLOT)
	restored.session_persistence.apply_save_data(save_data)
	await get_tree().process_frame
	_expect(restored.world_phase_orchestrator.get_current().id == &"phase.distant_heart", "Persisted story world did not restore after loading.")
	_expect(restored.get_world_progression().has_discovered(&"mystery.brothers_echo"), "Persisted world mysteries did not restore after loading.")
	restored.free()
	main.queue_free()
	await get_tree().process_frame
	SaveService.delete_slot(TEST_SLOT)
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip world content progression test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip world content progression test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
