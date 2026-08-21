class_name WorldMysteryDefinition
extends ContentDefinition

@export_multiline var discovery_text: String
@export var recipe_hint_id: StringName
@export var ingredient_hint_id: StringName


func validate() -> PackedStringArray:
	var messages := super()
	if discovery_text.strip_edges().is_empty():
		messages.append("World mystery '%s' has no discovery text." % id)
	return messages

