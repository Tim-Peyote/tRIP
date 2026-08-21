class_name WorldMysteryPOI
extends StaticBody3D

signal discovered(definition: WorldMysteryDefinition)

var definition: WorldMysteryDefinition
var _interactable: InteractableComponent
var _was_discovered: bool = false


func configure(value: WorldMysteryDefinition, interaction_center: Vector3 = Vector3.ZERO) -> void:
	definition = value
	collision_layer = 4
	collision_mask = 0
	_interactable = InteractableComponent.new()
	_interactable.name = "InteractableComponent"
	_interactable.object_name = definition.display_name if definition != null else "Неизвестный след"
	_interactable.primary_verb = "Изучить тайну места"
	_interactable.hold_duration = 0.85
	_interactable.inspection_description = definition.description if definition != null else "След не подчиняется обычной географии."
	_interactable.interaction_completed.connect(_on_interaction_completed)
	add_child(_interactable)
	var collision := CollisionShape3D.new()
	collision.name = "MysteryCollision"
	var shape := CylinderShape3D.new()
	shape.radius = 2.1
	shape.height = 3.8
	collision.shape = shape
	collision.position = interaction_center + Vector3.UP * 1.9
	add_child(collision)


func get_interaction_prompt(_actor: Node) -> String:
	if _was_discovered:
		return "Сверить запись: %s" % _interactable.object_name
	return "Изучить: %s" % _interactable.object_name


func _on_interaction_completed(_actor: Node, _action: StringName) -> void:
	if definition == null or _was_discovered:
		return
	_was_discovered = true
	discovered.emit(definition)
