extends Node

const PLAYER_SCENE := preload("res://features/player/player.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	ContentDB.rebuild()
	await get_tree().process_frame
	var player := PLAYER_SCENE.instantiate() as FirstPersonController
	add_child(player)
	await get_tree().process_frame

	var low := ItemInstance.new(&"item.spore_sight_brew", 2.0)
	low.quality = 0.2
	low.freshness = 0.45
	var high := ItemInstance.new(&"item.spore_sight_brew")
	high.quality = 0.9
	high.freshness = 0.95
	_expect(player.inventory.add_item(low) and player.inventory.add_item(high), "Test specimens did not enter the inventory.")
	_expect(player.inventory.get_specimens(low.definition_id)[0].instance_id == high.instance_id, "Specimen ordering is not deterministic by quality.")

	var consumed_quality := [-1.0]
	player.inventory.consumable_consumed.connect(func(_id: StringName, quality: float) -> void: consumed_quality[0] = quality)
	_expect(player.inventory.use_consumable_instance(low.instance_id), "The explicitly selected specimen could not be consumed.")
	_expect(is_equal_approx(float(consumed_quality[0]), 0.2), "Consumption ignored the selected specimen and used another quality.")
	var remaining_low := player.inventory.get_item(low.instance_id)
	_expect(remaining_low != null and is_equal_approx(remaining_low.quantity, 1.0), "Consuming from a quantity stack removed the wrong amount.")

	var split := ItemInstance.new(&"ingredient.mooncap", 2.0)
	_expect(player.inventory.add_item(split), "Split-stack probe did not enter the inventory.")
	var removed := player.inventory.remove_instance(split.instance_id)
	_expect(removed != null and removed.instance_id != split.instance_id, "A split stack duplicated one instance id across two physical specimens.")
	_expect(player.inventory.get_item(split.instance_id) != null, "Removing one unit destroyed the remaining stack.")
	_expect(player.inventory.add_item(removed), "The split specimen could not be restored.")

	var drop_id := removed.instance_id
	_expect(player.drop_inventory_item(drop_id), "Player could not drop the selected specimen into the world.")
	_expect(player.inventory.get_item(drop_id) == null, "Dropped specimen remained in the inventory.")
	var dropped: DroppedInventoryItem
	for child: Node in get_children():
		if child is DroppedInventoryItem:
			dropped = child as DroppedInventoryItem
			break
	_expect(dropped != null, "Dropping did not create a physical world object.")
	if dropped != null:
		_expect(player.interactor.try_grab_body(dropped), "Dropped inventory object could not be held by the physics interaction system.")
		_expect(player.interactor.is_holding_body(), "Physical hand did not retain the dropped object.")
		player.interactor.call("_release_grabbed_body")
		_expect(dropped.collect_into(player), "Dropped specimen could not be picked back up.")
		_expect(player.inventory.get_item(drop_id) != null, "Picked-up specimen did not preserve its identity.")

	var consume_target := InventoryActionButton.new()
	consume_target.inventory_action = "consume"
	var drop_target := InventoryActionButton.new()
	drop_target.inventory_action = "drop"
	var consumable_payload := {"kind": &"inventory_item", "instance_id": high.instance_id, "consumable": true}
	var raw_payload := {"kind": &"inventory_item", "instance_id": split.instance_id, "consumable": false}
	_expect(consume_target._can_drop_data(Vector2.ZERO, consumable_payload), "Consume target rejected a consumable drag payload.")
	_expect(not consume_target._can_drop_data(Vector2.ZERO, raw_payload), "Consume target accepted non-consumable raw material.")
	_expect(drop_target._can_drop_data(Vector2.ZERO, raw_payload), "World-drop target rejected a valid inventory item.")

	consume_target.free()
	drop_target.free()
	player.free()
	await get_tree().process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip inventory interaction test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip inventory interaction test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
