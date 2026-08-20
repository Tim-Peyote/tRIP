class_name ExpeditionClock
extends Node

signal time_changed(progress: float)
signal phase_changed(phase: int)

enum Phase { DAY, DUSK, NIGHT }

@export_range(30.0, 1800.0, 1.0, "suffix:s") var expedition_duration: float = 360.0
@export var running: bool = true

var progress: float = 0.0
var phase: Phase = Phase.DAY


func _process(delta: float) -> void:
	if running:
		set_progress(progress + delta / expedition_duration)


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	var next_phase := Phase.DAY
	if progress >= 0.72:
		next_phase = Phase.NIGHT
	elif progress >= 0.38:
		next_phase = Phase.DUSK
	if next_phase != phase:
		phase = next_phase
		phase_changed.emit(phase)
	time_changed.emit(progress)


func get_display_text() -> String:
	var names := ["ДЕНЬ", "СУМЕРКИ", "НОЧЬ"]
	var remaining := ceili((1.0 - progress) * expedition_duration)
	return "%s · %02d:%02d" % [names[phase], remaining / 60, remaining % 60]


func to_save_data() -> Dictionary:
	return {"progress": progress, "running": running}


func apply_save_data(data: Dictionary) -> void:
	running = bool(data.get("running", true))
	set_progress(float(data.get("progress", 0.0)))
