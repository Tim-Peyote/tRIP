class_name SporeShelterZone
extends Node3D

@export var shelter_name: String = "грибной навес"
@export_range(0.5, 8.0, 0.1) var protection_radius: float = 2.4
@export_range(0.0, 1.0, 0.05) var protection: float = 1.0


func get_protection_at(world_position: Vector3) -> float:
	var distance := Vector2(world_position.x - global_position.x, world_position.z - global_position.z).length()
	if distance >= protection_radius:
		return 0.0
	return protection * (1.0 - smoothstep(protection_radius * 0.72, protection_radius, distance))

