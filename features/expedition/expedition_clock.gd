class_name ExpeditionClock
extends Node

signal time_changed(progress: float)
signal phase_changed(phase: int)

enum Phase { DAY, DUSK, NIGHT }

const START_GAME_MINUTES: int = 216 # 03:36, matching the start of a new Valheim-like day.

@export_category("Real-time pacing")
@export_range(300.0, 3600.0, 1.0, "suffix:s") var cycle_duration: float = 1800.0
@export_range(0.15, 0.45, 0.01) var night_fraction: float = 0.3
@export_range(0.0, 0.12, 0.01) var dawn_fraction: float = 0.04
@export_range(0.04, 0.2, 0.01) var dusk_fraction: float = 0.12
@export var running: bool = true

var progress: float = 0.08
var phase: Phase = Phase.DAY
var elapsed_seconds: float = 0.0
var day_index: int = 1


func _process(delta: float) -> void:
	if running:
		advance(delta)


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	elapsed_seconds += delta
	var unwrapped := progress + delta / maxf(cycle_duration, 1.0)
	if unwrapped >= 1.0:
		var completed_days := floori(unwrapped)
		day_index += completed_days
		unwrapped -= float(completed_days)
	set_progress(unwrapped)


func set_progress(value: float) -> void:
	progress = fposmod(value, 1.0)
	var night_start := 1.0 - night_fraction + dawn_fraction
	var dusk_start := night_start - dusk_fraction
	var next_phase := Phase.DAY
	if progress < dawn_fraction or progress >= night_start:
		next_phase = Phase.NIGHT
	elif progress >= dusk_start:
		next_phase = Phase.DUSK
	if next_phase != phase:
		phase = next_phase
		phase_changed.emit(phase)
	time_changed.emit(progress)


func get_display_text() -> String:
	var names := ["ДЕНЬ", "СУМЕРКИ", "НОЧЬ"]
	var game_minutes := posmod(START_GAME_MINUTES + floori(progress * 1440.0), 1440)
	return "%s %d · %02d:%02d" % [names[phase], day_index, game_minutes / 60, game_minutes % 60]


func get_elapsed_seconds() -> float:
	return elapsed_seconds


func get_daylight_duration() -> float:
	return cycle_duration * (1.0 - night_fraction)


func get_night_duration() -> float:
	return cycle_duration * night_fraction


func to_save_data() -> Dictionary:
	return {
		"progress": progress,
		"running": running,
		"elapsed_seconds": elapsed_seconds,
		"day_index": day_index,
	}


func apply_save_data(data: Dictionary) -> void:
	running = bool(data.get("running", true))
	elapsed_seconds = maxf(0.0, float(data.get("elapsed_seconds", 0.0)))
	day_index = maxi(1, int(data.get("day_index", 1)))
	set_progress(float(data.get("progress", 0.08)))
