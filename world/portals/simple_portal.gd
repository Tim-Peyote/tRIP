class_name SimplePortal
extends StaticBody3D

signal traversed(actor: Node)

@export var target_position: Vector3
@export var target_yaw: float = 0.0
@export var portal_name: String = "Дверь в лес"
@export_multiline var portal_description: String = "За дверью влажный лес. Воздух уже пахнет спорами."
@onready var interactable: InteractableComponent = %InteractableComponent


func _ready() -> void:
	interactable.object_name = portal_name
	interactable.inspection_description = portal_description
	interactable.interaction_completed.connect(_on_interaction_completed)


func _on_interaction_completed(actor: Node, _action: StringName) -> void:
	if not actor is Node3D:
		return
	var actor_3d := actor as Node3D
	actor_3d.global_position = target_position
	actor_3d.rotation.y = target_yaw
	traversed.emit(actor)
