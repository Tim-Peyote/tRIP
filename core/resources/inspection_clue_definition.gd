class_name InspectionClueDefinition
extends Resource

@export var id: StringName
@export var label: String
@export_multiline var description: String
@export_range(-180.0, 180.0, 1.0, "suffix:°") var target_yaw: float = 0.0
@export_range(5.0, 90.0, 1.0, "suffix:°") var angle_tolerance: float = 28.0
@export_range(0.0, 1.0, 0.05) var minimum_zoom: float = 0.0


func validate(index: int) -> PackedStringArray:
	var messages := PackedStringArray()
	if id == &"":
		messages.append("Inspection clue %d has no id." % index)
	if label.strip_edges().is_empty():
		messages.append("Inspection clue %d has no label." % index)
	return messages
