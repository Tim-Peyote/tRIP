class_name RootWardZone
extends Node3D

@export var ward_name: String = "защитная мембрана"
@export_range(0.5, 8.0, 0.1, "suffix:m") var protection_radius: float = 2.2
@export_range(0.0, 1.0, 0.05) var protection: float = 1.0


func get_protection_at(world_position: Vector3) -> float:
	var distance := global_position.distance_to(world_position)
	if distance >= protection_radius:
		return 0.0
	return protection * smoothstep(protection_radius, protection_radius * 0.35, distance)
