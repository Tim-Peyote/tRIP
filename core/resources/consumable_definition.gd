class_name ConsumableDefinition
extends ItemDefinition

@export var effect_ids: Array[StringName] = []
@export_range(1, 16, 1) var doses: int = 1


func validate() -> PackedStringArray:
	var messages := super()
	if effect_ids.is_empty():
		messages.append("Consumable '%s' has no effects." % id)
	return messages

