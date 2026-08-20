class_name InspectionSession
extends RefCounted

signal clue_discovered(clue: InspectionClueDefinition)
signal completed

var definition: IngredientDefinition
var yaw: float = 0.0
var pitch: float = 0.0
var zoom: float = 0.0
var discovered: Dictionary[StringName, bool] = {}


func setup(value: IngredientDefinition) -> void:
	definition = value
	yaw = 0.0
	pitch = 0.0
	zoom = 0.0
	discovered.clear()


func rotate(yaw_delta: float, pitch_delta: float) -> void:
	yaw = wrapf(yaw + yaw_delta, -180.0, 180.0)
	pitch = clampf(pitch + pitch_delta, -55.0, 55.0)
	evaluate()


func set_zoom(value: float) -> void:
	zoom = clampf(value, 0.0, 1.0)
	evaluate()


func reveal_clue(clue_id: StringName) -> bool:
	if definition == null or discovered.has(clue_id):
		return false
	for clue: InspectionClueDefinition in definition.inspection_clues:
		if clue.id == clue_id:
			_discover(clue)
			return true
	return false


func evaluate() -> void:
	if definition == null:
		return
	for clue: InspectionClueDefinition in definition.inspection_clues:
		if discovered.has(clue.id) or zoom < clue.minimum_zoom:
			continue
		var angular_distance := absf(wrapf(yaw - clue.target_yaw + 180.0, 0.0, 360.0) - 180.0)
		if angular_distance <= clue.angle_tolerance:
			_discover(clue)


func is_complete() -> bool:
	return definition != null and not definition.inspection_clues.is_empty() and discovered.size() == definition.inspection_clues.size()


func _discover(clue: InspectionClueDefinition) -> void:
	discovered[clue.id] = true
	clue_discovered.emit(clue)
	if is_complete():
		completed.emit()
