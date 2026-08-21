class_name WorldMysteryDefinition
extends ContentDefinition

enum EventRule {
	HOLD_STILL,
	CROUCH_AND_LISTEN,
	KEEP_WALKING,
	RETREAT_WITHOUT_RUNNING,
	APPROACH_SLOWLY,
}

@export_multiline var discovery_text: String
@export var recipe_hint_id: StringName
@export var ingredient_hint_id: StringName
@export var event_rule: EventRule = EventRule.HOLD_STILL
@export_multiline var event_instruction: String
@export_multiline var failure_text: String
@export_range(1.0, 12.0, 0.1, "suffix:s") var event_duration: float = 3.5
@export_range(2.0, 16.0, 0.25, "suffix:m") var danger_radius: float = 7.0
@export_range(0.05, 1.0, 0.05) var pressure_rate: float = 0.28
@export var event_color: Color = Color(0.65, 0.85, 0.45)
@export_range(0.35, 2.5, 0.05) var audio_pitch: float = 1.0


func validate() -> PackedStringArray:
	var messages := super()
	if discovery_text.strip_edges().is_empty():
		messages.append("World mystery '%s' has no discovery text." % id)
	if event_instruction.strip_edges().is_empty():
		messages.append("World mystery '%s' has no event instruction." % id)
	return messages
