class_name BiomeHazardDefinition
extends Resource

enum CounterRule {
	HOLD_STILL,
	KEEP_MOVING,
	CROUCH_AND_LISTEN,
	WALK_SLOWLY,
	SEEK_HIGH_GROUND,
}

enum VisualFamily {
	WIND,
	SPORES,
	HUNT,
	SHARDS,
	ASH,
	RAIN,
	ROOTS,
	RESONANCE,
}

@export var id: StringName
@export var display_name: String
@export_multiline var warning_text: String
@export_multiline var active_text: String
@export_multiline var counter_text: String
@export_multiline var overwhelmed_text: String
@export var counter_rule: CounterRule = CounterRule.HOLD_STILL
@export var visual_family: VisualFamily = VisualFamily.WIND
@export_range(3.0, 180.0, 0.5, "suffix:s") var calm_duration: float = 34.0
@export_range(2.0, 60.0, 0.5, "suffix:s") var warning_duration: float = 7.0
@export_range(3.0, 90.0, 0.5, "suffix:s") var active_duration: float = 14.0
@export_range(0.01, 1.0, 0.01) var exposure_rate: float = 0.12
@export_range(0.01, 1.0, 0.01) var recovery_rate: float = 0.16
@export var primary_color: Color = Color(0.72, 0.82, 0.65)
@export var secondary_color: Color = Color(0.18, 0.28, 0.2)
@export_range(0.35, 2.5, 0.05) var audio_pitch: float = 1.0


func validate() -> PackedStringArray:
	var messages := PackedStringArray()
	if id == &"":
		messages.append("Biome hazard has no id.")
	if display_name.strip_edges().is_empty():
		messages.append("Biome hazard '%s' has no display name." % id)
	if counter_text.strip_edges().is_empty():
		messages.append("Biome hazard '%s' has no counter instruction." % id)
	return messages
