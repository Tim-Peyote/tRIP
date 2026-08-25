class_name InventoryActionButton
extends Button

signal inventory_payload_dropped(action: StringName, payload: Dictionary)

@export_enum("consume", "drop") var inventory_action: String = "drop"


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or StringName(data.get("kind", &"")) != &"inventory_item":
		return false
	if inventory_action == "consume":
		return bool(data.get("consumable", false))
	return inventory_action == "drop"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	inventory_payload_dropped.emit(StringName(inventory_action), (data as Dictionary).duplicate(true))
