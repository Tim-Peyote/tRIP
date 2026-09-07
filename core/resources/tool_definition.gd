class_name ToolDefinition
extends ItemDefinition

@export var capabilities: Array[StringName] = []
@export_range(0.0, 1.0, 0.01) var base_precision: float = 1.0
## Optional authored hand presentation, including its grip and item geometry.
## Local units match the hand bone socket. Never guess a grip for an unknown item.
@export var hand_scene: PackedScene


func validate() -> PackedStringArray:
	var messages := super()
	if capabilities.is_empty():
		messages.append("Tool '%s' has no capabilities." % id)
	return messages
