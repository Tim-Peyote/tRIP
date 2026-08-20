class_name ListenerCreature
extends CharacterBody3D

signal noise_heard(event: GameplayNoiseEvent)
signal state_changed(state: int)

enum State { IDLE, INVESTIGATE, ALERT, CHASE, SEARCH }

@export var movement_speed: float = 1.15
@export var hearing_multiplier: float = 1.0

var state: State = State.IDLE
var target_position: Vector3
@onready var sensor: PerceptionSensorComponent = %PerceptionSensorComponent


func _ready() -> void:
	sensor.noise_perceived.connect(_on_noise_perceived)
	sensor.suspicion_changed.connect(_on_suspicion_changed)
	sensor.target_lost.connect(_on_target_lost)


func get_sensor() -> PerceptionSensorComponent:
	return sensor


func hear_noise(event: GameplayNoiseEvent) -> void:
	sensor.receive_noise(event)


func _on_noise_perceived(event: GameplayNoiseEvent) -> void:
	target_position = event.origin
	state = State.ALERT if event.intensity >= 0.85 else State.INVESTIGATE
	noise_heard.emit(event)
	state_changed.emit(state)


func _on_suspicion_changed(value: float) -> void:
	if value >= 1.0 and sensor.target != null:
		state = State.CHASE
		target_position = sensor.target.global_position
		state_changed.emit(state)


func _on_target_lost() -> void:
	if state == State.CHASE:
		state = State.SEARCH
		state_changed.emit(state)


func _physics_process(_delta: float) -> void:
	if state == State.CHASE and sensor.target != null:
		target_position = sensor.target.global_position
	if state == State.IDLE:
		velocity = Vector3.ZERO
		return
	var direction := target_position - global_position
	direction.y = 0.0
	if direction.length() < 0.45:
		velocity = Vector3.ZERO
		var next_state := State.SEARCH if sensor.suspicion > 0.05 else State.IDLE
		if next_state != state:
			state = next_state
			state_changed.emit(state)
		return
	velocity = direction.normalized() * movement_speed
	look_at(global_position + direction, Vector3.UP)
	move_and_slide()
