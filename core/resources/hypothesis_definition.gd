class_name HypothesisDefinition
extends ContentDefinition

@export_multiline var question: String
@export var required_observation_ids: Array[StringName] = []
@export var suggested_item_ids: Array[StringName] = []
@export var approximate_region_id: StringName
@export var unlock_ids: Array[StringName] = []


func validate() -> PackedStringArray:
	var messages := super()
	if question.strip_edges().is_empty():
		messages.append("Hypothesis '%s' has no question." % id)
	return messages

