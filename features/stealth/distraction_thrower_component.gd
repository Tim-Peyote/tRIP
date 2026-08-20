class_name DistractionThrowerComponent
extends Node

signal projectile_created(projectile: DistractionProjectile)
signal count_changed(remaining: int)

@export var projectile_scene: PackedScene
@export_range(0, 12, 1) var starting_count: int = 3
var remaining: int


func _ready() -> void:
	remaining = starting_count


func throw(origin: Vector3, direction: Vector3) -> DistractionProjectile:
	if remaining <= 0 or projectile_scene == null:
		return null
	var projectile := projectile_scene.instantiate() as DistractionProjectile
	get_tree().current_scene.add_child(projectile)
	projectile.launch(origin, direction)
	remaining -= 1
	count_changed.emit(remaining)
	projectile_created.emit(projectile)
	return projectile
