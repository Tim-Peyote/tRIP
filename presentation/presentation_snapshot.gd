class_name PresentationSnapshot
extends RefCounted

var visual_intensity: float = 1.0
var perception: float = 0.0
var toxicity: float = 0.0
var danger: float = 0.0
var night: float = 0.0


func sanitized() -> PresentationSnapshot:
	var result := PresentationSnapshot.new()
	result.visual_intensity = clampf(visual_intensity, 0.0, 1.0)
	result.perception = clampf(perception, 0.0, 1.0)
	result.toxicity = clampf(toxicity, 0.0, 1.0)
	result.danger = clampf(danger, 0.0, 1.0)
	result.night = clampf(night, 0.0, 1.0)
	return result

