extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ContentDB.rebuild()
	_test_recipe_contract()
	_test_every_authored_recipe()
	_test_physical_vessel()
	await _test_station_and_persistence()
	_finish()


func _test_recipe_contract() -> void:
	var recipe := load("res://content/recipes/spore_sight_brew.tres") as RecipeDefinition
	var process := CookingProcess.new()
	var grind := CookingProcessEvent.new(&"grind", &"ingredient.mooncap", 1.0, 20.0, 8.0, 0.0)
	grind.ingredient_tags.assign([&"fungus", &"perception", &"part_cap"])
	process.append_event(grind)
	var heat := CookingProcessEvent.new(&"heat", &"ingredient.mooncap", 1.0, 80.0, 24.0, 8.0)
	heat.ingredient_tags.assign([&"fungus", &"perception", &"part_cap"])
	heat.stir_count = 2
	heat.homogeneity = 0.8
	heat.overheat_duration = 0.0
	process.append_event(heat)
	var resolver := RecipeResolver.new()
	var correct := resolver.resolve(process, recipe, &"base.water", RecipeDefinition.FinishMethod.BOTTLE, 0, 1)
	_expect(correct.quality == RecipeResolution.Quality.PURE, "Exact base, finish and clock turns did not produce PURE quality.")
	var wrong_base := resolver.resolve(process, recipe, &"base.spirit", RecipeDefinition.FinishMethod.BOTTLE, 0, 1)
	_expect(&"wrong_base" in wrong_base.explanation_tags, "Wrong liquid base was not diagnosed.")
	_expect(wrong_base.quality < RecipeResolution.Quality.WORKING, "Wrong liquid base still produced a usable batch.")
	var wrong_turns := resolver.resolve(process, recipe, &"base.water", RecipeDefinition.FinishMethod.BOTTLE, 0, 7)
	_expect(&"wrong_turn_count" in wrong_turns.explanation_tags, "Bad hourglass timing was not diagnosed.")
	var slightly_hot_process := _make_exact_process(recipe)
	var heat_event := slightly_hot_process.events[-1] as CookingProcessEvent
	heat_event.temperature = recipe.steps[-1].maximum_temperature + 2.0
	var slightly_hot := resolver.resolve(slightly_hot_process, recipe, recipe.required_base_id, recipe.finish_method, recipe.minimum_station_tier, recipe.steps[-1].minimum_hourglass_turns)
	var badly_hot_process := _make_exact_process(recipe)
	(badly_hot_process.events[-1] as CookingProcessEvent).temperature = recipe.steps[-1].maximum_temperature + 50.0
	var badly_hot := resolver.resolve(badly_hot_process, recipe, recipe.required_base_id, recipe.finish_method, recipe.minimum_station_tier, recipe.steps[-1].minimum_hourglass_turns)
	_expect(&"temperature_out_of_range" in slightly_hot.explanation_tags, "Small temperature error was not diagnosed.")
	_expect(slightly_hot.score > badly_hot.score, "Recipe scoring did not distinguish a near miss from a catastrophic temperature error.")


func _test_every_authored_recipe() -> void:
	var recipe_paths := [
		"res://content/recipes/ashen_bell_tea.tres",
		"res://content/recipes/crimson_marrow_stew.tres",
		"res://content/recipes/deep_root_kisel.tres",
		"res://content/recipes/emberberry_tonic.tres",
		"res://content/recipes/final_concordance.tres",
		"res://content/recipes/glass_lichen_decoction.tres",
		"res://content/recipes/mirror_reed_broth.tres",
		"res://content/recipes/spore_sight_brew.tres",
	]
	var ids: Array[StringName] = []
	var resolver := RecipeResolver.new()
	for path: String in recipe_paths:
		var recipe := load(path) as RecipeDefinition
		_expect(recipe != null, "Recipe resource failed to load: %s" % path)
		if recipe == null:
			continue
		_expect(recipe.validate().is_empty(), "Recipe contract is invalid: %s · %s" % [path, "; ".join(recipe.validate())])
		_expect(recipe.id not in ids, "Duplicate recipe id: %s" % recipe.id)
		ids.append(recipe.id)
		var heat_step := _find_heat_step(recipe)
		var turns := heat_step.minimum_hourglass_turns if heat_step != null else 0
		var resolution := resolver.resolve(_make_exact_process(recipe), recipe, recipe.required_base_id, recipe.finish_method, recipe.minimum_station_tier, turns)
		_expect(resolution.quality == RecipeResolution.Quality.PURE, "Authored recipe cannot produce PURE quality: %s (score %.2f, tags %s)" % [recipe.id, resolution.score, resolution.explanation_tags])
		if heat_step != null:
			var vessel := ThermalVesselState.new()
			vessel.configure_recipe(recipe)
			vessel.add_base(recipe.required_base_id, 1.0)
			vessel.add_ingredient(recipe.primary_ingredient_id, 1.0, [heat_step.ingredient_tag])
			var working_temperature := (heat_step.minimum_temperature + heat_step.maximum_temperature) * 0.5
			vessel.temperature = working_temperature
			for stir_index: int in heat_step.minimum_stirs:
				vessel.stir()
			for tick: int in ceili(heat_step.minimum_duration / 0.1) + 1:
				vessel.temperature = working_temperature
				vessel.simulate(0.1)
			_expect(vessel.is_ready(), "Physical controls cannot satisfy authored recipe: %s" % recipe.id)


func _make_exact_process(recipe: RecipeDefinition) -> CookingProcess:
	var process := CookingProcess.new()
	for step: RecipeStepDefinition in recipe.steps:
		var event := CookingProcessEvent.new(
			step.operation,
			recipe.primary_ingredient_id,
			(step.minimum_amount + step.maximum_amount) * 0.5,
			(step.minimum_temperature + step.maximum_temperature) * 0.5,
			(step.minimum_duration + step.maximum_duration) * 0.5,
			0.0
		)
		if step.ingredient_tag != &"":
			event.ingredient_tags.append(step.ingredient_tag)
		if step.operation == &"heat":
			event.stir_count = step.minimum_stirs
			event.homogeneity = step.minimum_homogeneity
			event.overheat_duration = 0.0
		process.append_event(event)
	return process


func _find_heat_step(recipe: RecipeDefinition) -> RecipeStepDefinition:
	for step: RecipeStepDefinition in recipe.steps:
		if step.operation == &"heat":
			return step
	return null


func _test_physical_vessel() -> void:
	var vessel := ThermalVesselState.new()
	var advanced_recipe := load("res://content/recipes/mirror_reed_broth.tres") as RecipeDefinition
	var heat_step := _find_heat_step(advanced_recipe)
	vessel.configure_recipe(advanced_recipe)
	_expect(is_equal_approx(vessel.target_temperature_min, heat_step.minimum_temperature), "Vessel ignored recipe-specific minimum temperature.")
	_expect(is_equal_approx(vessel.target_temperature_max, heat_step.maximum_temperature), "Vessel ignored recipe-specific maximum temperature.")
	_expect(is_equal_approx(vessel.required_effective_duration, heat_step.minimum_duration), "Vessel ignored recipe-specific duration.")
	vessel.add_base(advanced_recipe.required_base_id, 1.0)
	vessel.add_ingredient(advanced_recipe.primary_ingredient_id, 1.0, [])
	vessel.temperature = (heat_step.minimum_temperature + heat_step.maximum_temperature) * 0.5
	vessel.simulate(1.0)
	_expect(is_equal_approx(vessel.effective_target_duration, 1.0), "Recipe duration ran at a different speed than the physical hourglass.")
	vessel.reset()
	_expect(vessel.add_base(&"base.spirit", 1.0), "Vessel rejected a valid spirit base.")
	_expect(not vessel.add_base(&"base.water", 1.0), "Vessel mixed mutually exclusive bases.")
	vessel.cycle_heat()
	vessel.toggle_vessel_position()
	for index: int in 100:
		vessel.simulate(0.1)
	_expect(vessel.temperature < 55.0, "Raised vessel heated as if it remained in direct fire.")
	vessel.toggle_vessel_position()
	_expect(vessel.pump_bellows(), "Lit fire rejected bellows input.")
	_expect(vessel.fire_momentum > 0.0, "Bellows did not strengthen the fire.")
	_expect(vessel.flip_hourglass(), "Hourglass did not start.")
	for index: int in 81:
		vessel.simulate(0.1)
	_expect(vessel.completed_hourglass_turns == 1, "Hourglass did not record a completed turn.")


func _test_station_and_persistence() -> void:
	var level := (load("res://world/levels/shelter/shelter_level.tscn") as PackedScene).instantiate() as ShelterLevel
	add_child(level)
	await get_tree().process_frame
	var portable := level.road_laboratory.get_node("PortableLaboratory")
	for tool_name: String in ["KvassJug", "SpiritFlask", "PotCrane", "Bellows", "Hourglass", "Distiller", "ServingBowl"]:
		_expect(portable.has_node(tool_name), "Portable laboratory is missing %s." % tool_name)
	_expect(not (portable.get_node("Distiller") as Node3D).visible, "Distiller appeared before the first laboratory upgrade.")
	level.cooking_orchestrator.batches_completed = 6
	level.cooking_orchestrator.station_tier = 2
	level.cooking_orchestrator.mastery_changed.emit(2, 6)
	_expect((portable.get_node("Distiller") as Node3D).visible, "Mastery upgrade did not reveal the distiller.")
	_expect((portable.get_node("SpiritFlask") as Node3D).visible, "Second mastery tier did not reveal the spirit base.")
	var saved := level.cooking_orchestrator.to_save_data()
	var restored := CookingOrchestrator.new()
	level.add_child(restored)
	restored.recipes = level.cooking_orchestrator.recipes
	restored.recipe = level.cooking_orchestrator.recipe
	restored.apply_save_data(saved)
	_expect(restored.batches_completed == 6 and restored.station_tier == 2, "Cooking mastery did not survive save/load.")
	var failed := RecipeResolution.new()
	failed.explanation_tags.assign([&"wrong_base", &"temperature_out_of_range"])
	level.recipe_knowledge_orchestrator._on_batch_evaluated(&"recipe.spore_sight_brew", failed)
	var knowledge_saved := level.recipe_knowledge_orchestrator.to_save_data()
	var restored_knowledge := RecipeKnowledgeOrchestrator.new()
	level.add_child(restored_knowledge)
	restored_knowledge.setup(level.cooking_orchestrator)
	restored_knowledge.apply_save_data(knowledge_saved)
	var restored_entry: Dictionary = {}
	for entry: Dictionary in restored_knowledge.get_entries():
		if StringName(entry["id"]) == &"recipe.spore_sight_brew":
			restored_entry = entry
	_expect(int(restored_entry.get("attempt_count", 0)) == 1, "Failed recipe attempt did not survive save/load.")
	_expect((restored_entry.get("observations", []) as Array).size() == 2, "Recipe observations did not survive save/load.")
	level.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip alchemy workflow test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip alchemy workflow test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
