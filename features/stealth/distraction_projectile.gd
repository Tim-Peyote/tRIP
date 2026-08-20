class_name DistractionProjectile
extends RigidBody3D

signal impacted(projectile: DistractionProjectile)

@onready var noise_emitter: NoiseEmitterComponent = %NoiseEmitterComponent
var _spent: bool = false


func launch(origin: Vector3, direction: Vector3) -> void:
	global_position = origin
	linear_velocity = direction.normalized() * 8.5 + Vector3.UP * 2.2


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	%FallbackTimer.timeout.connect(_impact)


func _on_body_entered(_body: Node) -> void:
	_impact()


func _impact() -> void:
	if _spent:
		return
	_spent = true
	noise_emitter.emit_noise(10.0, &"thrown_stone", 0.9)
	impacted.emit(self)
	%DespawnTimer.start()


func _on_despawn_timer_timeout() -> void:
	queue_free()
