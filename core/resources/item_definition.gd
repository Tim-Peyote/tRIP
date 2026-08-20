class_name ItemDefinition
extends ContentDefinition

@export_range(0.0, 50.0, 0.01, "suffix:kg") var mass: float = 0.1
@export_range(0.0, 50.0, 0.01) var volume: float = 0.1
@export var max_stack: int = 1
@export var world_scene: PackedScene
@export var inventory_icon: Texture2D


func validate() -> PackedStringArray:
	var messages := super()
	if mass < 0.0 or volume < 0.0:
		messages.append("Item '%s' has negative mass or volume." % id)
	if max_stack < 1:
		messages.append("Item '%s' max_stack must be at least 1." % id)
	return messages

