extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ContentDB.rebuild()
	_test_recipe_contract()
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


func _test_physical_vessel() -> void:
	var vessel := ThermalVesselState.new()
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
