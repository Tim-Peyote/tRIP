class_name EffectDefinition
extends ContentDefinition

@export_category("Timing")
@export_range(0.1, 3600.0, 0.1, "suffix:s") var duration_seconds: float = 30.0
@export var onset_curve: Curve
@export var decay_curve: Curve

@export_category("Gameplay Channels")
@export var gameplay_channels: Dictionary[StringName, float] = {}

@export_category("Presentation Channels")
@export var presentation_channels: Dictionary[StringName, float] = {}

@export_category("Design Contract")
@export_multiline var opportunity: String
@export_multiline var price: String
@export_multiline var tell: String
@export_multiline var counterplay: String
@export_multiline var world_reaction: String


func validate() -> PackedStringArray:
	var messages := super()
	if duration_seconds <= 0.0:
		messages.append("Effect '%s' must have a positive duration." % id)
	if opportunity.strip_edges().is_empty():
		messages.append("Effect '%s' has no player opportunity." % id)
	if price.strip_edges().is_empty():
		messages.append("Effect '%s' has no price/tradeoff." % id)
	return messages

