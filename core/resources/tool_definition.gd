class_name ToolDefinition
extends ItemDefinition

@export var capabilities: Array[StringName] = []
@export_range(0.0, 1.0, 0.01) var base_precision: float = 1.0


func validate() -> PackedStringArray:
	var messages := super()
	if capabilities.is_empty():
		messages.append("Tool '%s' has no capabilities." % id)
	return messages

