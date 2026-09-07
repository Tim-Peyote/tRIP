extends Node

var _failures: Array[String] = []


func _ready() -> void:
	_expect(ContentDB.rebuild(), "Content database did not rebuild.")
	var actor := Node3D.new()
	actor.name = "TestActor"
	add_child(actor)
	var inventory := InventoryComponent.new()
	inventory.name = "InventoryComponent"
	actor.add_child(inventory)
	var toolbelt := ToolbeltComponent.new()
	toolbelt.name = "ToolbeltComponent"
	toolbelt.starter_tool_ids = [&"tool.field_shovel"]
	actor.add_child(toolbelt)
	await get_tree().process_frame

	var table := _make_table()
	var cache := WorldLootContainer.new()
	cache.configure(&"test.cache", table, 1337, "Тестовый тайник")
	add_child(cache)
	await get_tree().process_frame
	cache.debug_open_and_transfer(actor)
	_expect(inventory.count(&"ingredient.mooncap") > 0.0, "Container did not transfer loot into the inventory.")
	_expect((cache.to_save_data()["contents"] as Array).is_empty(), "Depleted container retained transferred loot.")

	var reloaded := WorldLootContainer.new()
	reloaded.configure(&"test.cache", table, 1337, "Тестовый тайник")
	add_child(reloaded)
	await get_tree().process_frame
	reloaded.apply_save_data(cache.to_save_data())
	reloaded.debug_open_and_transfer(actor)
	_expect(is_equal_approx(inventory.count(&"ingredient.mooncap"), 1.0), "Reloading a depleted container duplicated loot.")

	var cramped_actor := Node3D.new()
	cramped_actor.name = "CrampedActor"
	add_child(cramped_actor)
	var cramped_inventory := InventoryComponent.new()
	cramped_inventory.name = "InventoryComponent"
	cramped_inventory.maximum_mass = 0.01
	cramped_inventory.maximum_volume = 0.01
	cramped_actor.add_child(cramped_inventory)
	var full_cache := WorldLootContainer.new()
	full_cache.configure(&"test.full_cache", table, 17, "Переполненный тест")
	add_child(full_cache)
	await get_tree().process_frame
	full_cache.debug_open_and_transfer(cramped_actor)
	_expect(not (full_cache.to_save_data()["contents"] as Array).is_empty(), "Rejected loot vanished instead of remaining in its container.")
	cramped_inventory.maximum_mass = 12.0
	cramped_inventory.maximum_volume = 8.0
	full_cache.debug_open_and_transfer(cramped_actor)
	_expect(cramped_inventory.count(&"ingredient.mooncap") > 0.0, "Loot could not be retried after inventory capacity became available.")

	var site := ExcavationSite.new()
	site.required_stages = 3
	site.configure(&"test.excavation", table, 2026)
	add_child(site)
	await get_tree().process_frame
	_expect(site.can_receive_interaction(actor), "Equipped shovel did not grant the dig capability.")
	var untooled_actor := Node3D.new()
	untooled_actor.name = "UntooledActor"
	add_child(untooled_actor)
	var untooled_belt := ToolbeltComponent.new()
	untooled_belt.name = "ToolbeltComponent"
	untooled_belt.starter_tool_ids = []
	untooled_actor.add_child(untooled_belt)
	await get_tree().process_frame
	_expect(not site.can_receive_interaction(untooled_actor), "Excavation accepted an actor without a digging tool.")
	for step: int in 3:
		site.debug_advance(actor)
	_expect(int(site.to_save_data()["stage"]) == 3, "Excavation did not advance through all soil layers.")
	var saved_site := site.to_save_data()
	site.debug_advance(actor)
	_expect(inventory.count(&"ingredient.mooncap") > 1.0, "Excavation loot did not enter the inventory.")

	var resumed_site := ExcavationSite.new()
	resumed_site.configure(&"test.excavation", table, 2026)
	add_child(resumed_site)
	await get_tree().process_frame
	resumed_site.apply_save_data(saved_site)
	_expect(int(resumed_site.to_save_data()["stage"]) == 3, "Excavation progress was not restored.")

	actor.free()
	cramped_actor.free()
	untooled_actor.free()
	cache.free()
	reloaded.free()
	full_cache.free()
	site.free()
	resumed_site.free()
	_finish()


func _make_table() -> LootTableDefinition:
	var entry := LootEntryDefinition.new()
	entry.definition_id = &"ingredient.mooncap"
	entry.guaranteed = true
	entry.chance = 1.0
	entry.minimum_quantity = 1.0
	entry.maximum_quantity = 1.0
	entry.minimum_quality = 0.7
	entry.maximum_quality = 0.7
	var table := LootTableDefinition.new()
	table.id = &"test.loot"
	table.rolls = 1
	table.entries.append(entry)
	return table


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip world loot interaction test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip world loot interaction test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
