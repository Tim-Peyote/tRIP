class_name RecipeStepDefinition
extends Resource

@export var operation: StringName
@export var ingredient_tag: StringName
@export_range(0.0, 1000.0, 0.01) var minimum_amount: float = 0.0
@export_range(0.0, 1000.0, 0.01) var maximum_amount: float = 1000.0
@export_range(-50.0, 300.0, 0.1, "suffix:°C") var minimum_temperature: float = -50.0
@export_range(-50.0, 300.0, 0.1, "suffix:°C") var maximum_temperature: float = 300.0
@export_range(0.0, 3600.0, 0.1, "suffix:s") var minimum_duration: float = 0.0
@export_range(0.0, 3600.0, 0.1, "suffix:s") var maximum_duration: float = 3600.0
@export_range(0, 20, 1) var minimum_stirs: int = 0
@export_range(0.0, 1.0, 0.01) var minimum_homogeneity: float = 0.0
@export_range(0.0, 120.0, 0.1, "suffix:s") var maximum_overheat_duration: float = 120.0
@export_range(0, 12, 1) var minimum_hourglass_turns: int = 0
@export_range(0, 12, 1) var maximum_hourglass_turns: int = 12
@export var sensory_cue: StringName
@export_multiline var player_hint: String


func validate(index: int) -> PackedStringArray:
	var messages := PackedStringArray()
	if operation == &"":
		messages.append("Step %d has no operation." % index)
	if minimum_amount > maximum_amount:
		messages.append("Step %d amount range is inverted." % index)
	if minimum_temperature > maximum_temperature:
		messages.append("Step %d temperature range is inverted." % index)
	if minimum_duration > maximum_duration:
		messages.append("Step %d duration range is inverted." % index)
	if minimum_hourglass_turns > maximum_hourglass_turns:
		messages.append("Step %d hourglass range is inverted." % index)
	return messages
