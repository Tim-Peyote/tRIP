extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://app/main/main.tscn") as PackedScene
	var main := packed.instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 90, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	_expect(level != null, "Main flow did not create ShelterLevel.")
	if level == null:
		_finish(main)
		return
	var player := level.get_player()
	var cooking := level.get_cooking_orchestrator()
	var harvested_cap := ItemInstance.new(&"ingredient.mooncap", 1.0)
	harvested_cap.quality = 1.0
	harvested_cap.processing_state[&"part"] = &"cap"
	player.inventory.add_item(harvested_cap)
	var tags: Array[StringName] = [&"fungus", &"perception"]
	var ground := cooking.perform_action(
		player, &"grind", &"ingredient.mooncap", tags, 1.0, 20.0, 8.0, &"ingredient.mooncap"
	)
	_expect(ground, "Mortar action was rejected.")
	_expect(player.inventory.count(&"ingredient.mooncap") == 0.0, "Mortar did not consume mooncap.")
	_expect(level.cooking_station_visuals.mortar_contents.visible, "Mortar visual state did not show ground ingredient.")
	var heated := cooking.perform_action(
		player, &"heat", &"ingredient.mooncap", tags, 1.0, 80.0, 24.0
	)
	_expect(heated, "Cauldron action was rejected.")
	_expect(player.inventory.count(&"item.spore_sight_brew") == 1.0, "Recipe did not create spore sight brew.")
	_expect(level.cooking_station_visuals.active_liquid.visible, "Cauldron visual state did not activate liquid.")
	_expect(level.cooking_station_visuals.steam.visible, "Cauldron visual state did not activate steam.")
	var used := player.inventory.use_first_consumable()
	_expect(used, "Quick use did not consume the brew.")
	await get_tree().process_frame
	_expect(main.effect_orchestrator.has_effect(&"effect.spore_sight"), "EffectOrchestrator did not activate spore sight.")
	_expect(level.hidden_mycelium.visible, "Spore sight did not reveal gameplay geometry.")
	_expect(player.inventory.count(&"item.spore_sight_brew") == 0.0, "Consumed brew remained in inventory.")
	_finish(main)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(main: TripMain) -> void:
	main.effect_orchestrator.clear()
	main.free()
	if _failures.is_empty():
		print("TRip cooking/effect test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip cooking/effect test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
