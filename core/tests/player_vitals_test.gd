extends Node

const PLAYER_SCENE := preload("res://features/player/player.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	ContentDB.rebuild()
	await get_tree().process_frame
	var player := PLAYER_SCENE.instantiate() as FirstPersonController
	add_child(player)
	await get_tree().process_frame
	var vitals := player.vitals
	_expect(is_equal_approx(vitals.get_maximum_health(), 35.0), "Base health is not the authored 35 points.")
	_expect(is_equal_approx(vitals.get_maximum_stamina(), 60.0), "Base stamina is not the authored 60 points.")

	player.inventory.add_item(ItemInstance.new(&"item.spore_sight_brew"))
	_expect(player.inventory.use_consumable(&"item.spore_sight_brew"), "First consciousness brew could not be consumed.")
	_expect(vitals.active_foods.size() == 1, "Consumed brew did not occupy one metabolic slot.")
	_expect(vitals.get_maximum_health() > 35.0 and vitals.get_maximum_stamina() > 60.0, "Food did not raise health and stamina capacity.")
	_expect(vitals.toxicity > 0.0, "Psychotropic brew created no toxic burden.")

	player.inventory.add_item(ItemInstance.new(&"item.crimson_marrow_stew"))
	_expect(player.inventory.use_consumable(&"item.crimson_marrow_stew"), "Replacement consciousness brew could not be consumed.")
	_expect(vitals.active_foods.size() == 1, "A brew from the same nutrition group did not replace its predecessor.")
	_expect(StringName(vitals.active_foods[0]["id"]) == &"item.crimson_marrow_stew", "Wrong food remained after same-group replacement.")

	player.inventory.add_item(ItemInstance.new(&"item.emberberry_tonic"))
	_expect(player.inventory.use_consumable(&"item.emberberry_tonic"), "Counteragent could not occupy a second food slot.")
	_expect(vitals.active_foods.size() == 2, "Different nutrition groups did not coexist.")

	var meal := _fake_food(&"meal_probe", &"meal")
	vitals.call("_apply_food", meal, 1.0)
	_expect(vitals.active_foods.size() == PlayerVitalsComponent.MAX_FOOD_SLOTS, "Third food slot was not accepted.")
	_expect(not vitals.can_consume(_fake_food(&"fourth_probe", &"fourth")), "Fourth distinct food ignored the metabolic slot limit.")

	var stamina_before := vitals.current_stamina
	_expect(vitals.spend_stamina(13.0, &"test_jump"), "Stamina could not pay a normal jump cost.")
	_expect(vitals.current_stamina < stamina_before, "Activity did not consume stamina.")
	vitals.set_environment(1.0, 14.0, -18.0)
	for _step: int in 120:
		vitals.call("_process", 0.25)
	_expect(vitals.core_temperature < PlayerVitalsComponent.NORMAL_CORE_TEMPERATURE, "Wet freezing weather did not cool the character.")

	vitals.set_spore_exposure(1.0)
	for _step: int in 60:
		vitals.call("_process", 0.25)
	_expect(vitals.spore_load > 0.1, "Environmental spore exposure did not reach the body model.")

	var saved := vitals.to_save_data()
	vitals.developer_restore()
	vitals.apply_save_data(saved)
	_expect(vitals.active_foods.size() == 3, "Metabolic slots did not survive persistence.")
	_expect(vitals.spore_load > 0.1, "Acute body burden did not survive persistence.")

	var collapse_count := [0]
	vitals.incapacitated.connect(func(_source: StringName) -> void: collapse_count[0] += 1)
	vitals.apply_damage(999.0, &"test")
	_expect(collapse_count[0] == 1 and not vitals.can_act(), "Zero health did not produce a single incapacitation state.")
	vitals.recover_after_incapacitation()
	_expect(vitals.can_act() and vitals.current_health > 0.0, "Recovery did not restore player agency.")

	player.free()
	_finish()


func _fake_food(id: StringName, group: StringName) -> ConsumableDefinition:
	var result := ConsumableDefinition.new()
	result.id = id
	result.display_name = String(id)
	result.nutrition_group = group
	result.nutrition_duration_seconds = 120.0
	result.maximum_health_bonus = 5.0
	result.maximum_stamina_bonus = 7.0
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip player vitals test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip player vitals test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
