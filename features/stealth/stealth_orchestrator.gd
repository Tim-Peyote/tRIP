class_name StealthOrchestrator
extends Node

signal threat_changed(value: float, state_text: String)

var _sensors: Array[PerceptionSensorComponent] = []
var _threat: float = 0.0


func setup(player: FirstPersonController, creatures: Array[ListenerCreature]) -> void:
	for creature: ListenerCreature in creatures:
		var sensor := creature.get_sensor()
		sensor.setup_target(player)
		sensor.suspicion_changed.connect(_recalculate_threat)
		_sensors.append(sensor)
	connect_noise_emitter(player.noise_emitter)
	_recalculate_threat()


func connect_noise_emitter(emitter: NoiseEmitterComponent) -> void:
	if emitter == null:
		return
	for sensor: PerceptionSensorComponent in _sensors:
		if not emitter.gameplay_noise_emitted.is_connected(sensor.receive_noise):
			emitter.gameplay_noise_emitted.connect(sensor.receive_noise)


func get_threat() -> float:
	return _threat


func _recalculate_threat(_unused: float = 0.0) -> void:
	_threat = 0.0
	for sensor: PerceptionSensorComponent in _sensors:
		_threat = maxf(_threat, sensor.suspicion)
	var state_text := "СКРЫТ" 
	if _threat >= 1.0:
		state_text = "ОБНАРУЖЕН"
	elif _threat >= 0.55:
		state_text = "ТРЕВОГА"
	elif _threat > 0.05:
		state_text = "ПОДОЗРЕНИЕ"
	threat_changed.emit(_threat, state_text)
