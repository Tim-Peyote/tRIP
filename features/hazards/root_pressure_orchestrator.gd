class_name RootPressureOrchestrator
extends Node

signal state_changed(state: int, label: String)
signal pressure_changed(value: float)
signal ward_changed(is_warded: bool, ward_name: String)
signal area_changed(is_inside: bool)
signal overwhelmed

enum State { REST, LISTENING, HUNTING }

@export_range(4.0, 120.0, 0.5, "suffix:s") var rest_duration: float = 18.0
@export_range(4.0, 120.0, 0.5, "suffix:s") var listening_duration: float = 13.0
@export_range(4.0, 120.0, 0.5, "suffix:s") var hunting_duration: float = 9.0
@export var bounds: AABB = AABB(Vector3(-9, -8, -15), Vector3(18, 12, 30))
@export var return_position: Vector3 = Vector3(0, 0.2, 11)

var state: State = State.REST
var pressure: float = 0.0
var plan_id: StringName = &""
var _elapsed: float = 0.0
var _player: FirstPersonController
var _anchor: Node3D
var _wards: Array[Node3D] = []
var _active_ward: Node3D
var _is_inside: bool = false


func _process(delta: float) -> void:
	_advance_cycle(delta)
	_update_pressure(delta)


func setup(player: FirstPersonController, anchor: Node3D) -> void:
	_player = player
	_anchor = anchor
	_wards.clear()
	for node: Node in anchor.find_children("*", "Node3D", true, false):
		if node.has_method("get_protection_at"):
			_wards.append(node as Node3D)
	_emit_state()
	pressure_changed.emit(pressure)


func set_plan(value: StringName) -> void:
	plan_id = value


func force_state(value: State) -> void:
	state = value
	_elapsed = 0.0
	_emit_state()


func _advance_cycle(delta: float) -> void:
	_elapsed += delta
	var duration := rest_duration
	if state == State.LISTENING:
		duration = listening_duration
	elif state == State.HUNTING:
		duration = hunting_duration
	if _elapsed < duration:
		return
	_elapsed = 0.0
	state = ((int(state) + 1) % 3) as State
	_emit_state()


func _update_pressure(delta: float) -> void:
	var inside := _player != null and _anchor != null and bounds.has_point(_anchor.to_local(_player.global_position))
	if inside != _is_inside:
		_is_inside = inside
		area_changed.emit(_is_inside)
	if not inside:
		_set_active_ward(null)
		_set_pressure(move_toward(pressure, 0.0, delta * 0.12))
		return
	var protection := _get_ward_protection()
	var rate := -0.09
	if state == State.LISTENING:
		rate = 0.035
	elif state == State.HUNTING:
		rate = 0.12
	var plan_multiplier := 0.38 if plan_id == &"warded_descent" else 1.3
	var movement_exposure := _player.get_stealth_exposure()
	var protected_rate := lerpf(rate * plan_multiplier * movement_exposure, -0.14, protection)
	_set_pressure(pressure + protected_rate * delta)
	if pressure >= 1.0:
		pressure = 0.36
		_player.global_position = _anchor.to_global(return_position)
		_player.velocity = Vector3.ZERO
		pressure_changed.emit(pressure)
		overwhelmed.emit()


func _get_ward_protection() -> float:
	var result := 0.0
	var best: Node3D
	for ward: Node3D in _wards:
		var value := float(ward.call("get_protection_at", _player.global_position))
		if value > result:
			result = value
			best = ward
	_set_active_ward(best)
	return result


func _set_active_ward(value: Node3D) -> void:
	if _active_ward == value:
		return
	_active_ward = value
	var ward_name := String(value.get("ward_name")) if value != null else ""
	ward_changed.emit(value != null, ward_name)


func _set_pressure(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	if is_equal_approx(next, pressure):
		return
	pressure = next
	pressure_changed.emit(pressure)


func _emit_state() -> void:
	var labels := ["КОРНИ СПЯТ", "КОРНИ СЛУШАЮТ", "КОРНИ ИЩУТ"]
	state_changed.emit(state, labels[state])
