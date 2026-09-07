extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ContentDB.rebuild()
	var level := (load("res://core/tests/fixtures/legacy_expedition_fixture.tscn") as PackedScene).instantiate() as LegacyExpeditionFixture
	add_child(level)
	await get_tree().process_frame
	level.expedition_clock.running = false
	var sample := ItemInstance.new(&"ingredient.mirror_reed")
	sample.quality = 1.0
	sample.processing_state[&"part"] = &"whole"
	level.player.inventory.add_item(sample)
	var portable := level.road_laboratory.get_laboratory_root()
	_complete_tool(portable.get_node("WashBasin"), level.player)
	_complete_tool(portable.get_node("PrepBoard"), level.player)
	_complete_tool(portable.get_node("Mortar"), level.player)
	var events := level.cooking_orchestrator.process.events
	_expect(events.size() == 3, "Advanced preparation did not record three physical stages.")
	if events.size() == 3:
		_expect(events[0].operation == &"wash", "Wash basin did not become the first preparation stage.")
		_expect(events[1].operation == &"slice", "Preparation knife did not preserve the active sample.")
		_expect(events[2].operation == &"grind", "Mortar did not accept the washed and sliced sample.")
	_expect(level.player.inventory.count(&"ingredient.mirror_reed") == 0.0, "Preparation consumed the same sample more than once or not at all.")
	_expect(level.cooking_orchestrator.add_water(), "Advanced preparation could not fill the vessel.")
	_expect(level.cooking_orchestrator.transfer_prepared_ingredient(), "A multi-stage prepared sample could not enter the vessel.")
	_expect(level.cooking_orchestrator.vessel.ingredient_id == &"ingredient.mirror_reed", "The vessel lost the prepared sample identity.")
	level.free()
	_finish()


func _complete_tool(body: Node, actor: Node) -> void:
	var interactable := body.get_node("InteractableComponent") as InteractableComponent
	interactable.complete_interaction(actor)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip advanced preparation test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip advanced preparation test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
