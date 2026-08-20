class_name ContentDefinition
extends Resource

@export_category("Identity")
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var tags: Array[StringName] = []


func validate() -> PackedStringArray:
	var messages := PackedStringArray()
	if id == &"":
		messages.append("Content id is empty.")
	elif not String(id).is_valid_filename():
		messages.append("Content id must be filename-safe: '%s'." % id)
	if display_name.strip_edges().is_empty():
		messages.append("Display name is empty for '%s'." % id)
	return messages

