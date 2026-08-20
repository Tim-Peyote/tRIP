class_name SporeTideOrchestrator
extends Node

signal state_changed(state: int, label: String)
signal exposure_changed(value: float)
signal overwhelmed

enum State { CALM, RISING, SURGE }

@export var calm_duration: float = 20.0
@export var rising_duration: float = 12.0
@export var surge_duration: float = 16.0
@export var local_safe_position: Vector3 = Vector3(-4.5, 0.12, 0)
@export var zone_half_extents: Vector2 = Vector2(15, 15)

var state: State = State.CALM
var exposure: float = 0.0
var _phase_time: float = 0.0
var _spore_resistance: float = 0.0
var _spore_attraction: float = 0.0
var _player: FirstPersonController


func setup(player: FirstPersonController) -> void:
	_player = player
	_emit_state()


func apply_gameplay_channels(channels: Dictionary[StringName, float]) -> void:
	_spore_resistance = float(channels.get(&"spore_resistance", 0.0))
	_spore_attraction = float(channels.get(&"spore_vision", 0.0))


func _process(delta: float) -> void:
	_phase_time += delta
	var duration := _get_duration()
	if _phase_time >= duration:
		_phase_time = 0.0
		state = wrapi(state + 1, State.CALM, State.SURGE + 1) as State
		_emit_state()
	if _player == null or not _is_player_inside():
		exposure = move_toward(exposure, 0.0, delta * 0.08)
		exposure_changed.emit(exposure)
		return
	var rate := -0.07
	if state == State.RISING:
		rate = 0.022
	elif state == State.SURGE:
		rate = 0.085
	var resistance_multiplier := lerpf(1.0, 0.12, _spore_resistance)
	var attraction_multiplier := lerpf(1.0, 1.45, _spore_attraction)
	exposure = clampf(exposure + rate * resistance_multiplier * attraction_multiplier * delta, 0.0, 1.0)
	exposure_changed.emit(exposure)
	if exposure >= 1.0:
		exposure = 0.35
		_player.global_position = (get_parent() as Node3D).to_global(local_safe_position)
		overwhelmed.emit()
		exposure_changed.emit(exposure)


func force_state(value: State) -> void:
	state = value
	_phase_time = 0.0
	_emit_state()


func _is_player_inside() -> bool:
	var local_position := (get_parent() as Node3D).to_local(_player.global_position)
	return absf(local_position.x) <= zone_half_extents.x and absf(local_position.z) <= zone_half_extents.y


func _get_duration() -> float:
	match state:
		State.CALM:
			return calm_duration
		State.RISING:
			return rising_duration
		_:
			return surge_duration


func _emit_state() -> void:
	var labels := ["СПОРЫ СПЯТ", "СПОРОВЫЙ ПРИЛИВ ПОДНИМАЕТСЯ", "СПОРОВЫЙ ПРИЛИВ"]
	state_changed.emit(state, labels[state])

