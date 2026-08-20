class_name CollectibleIngredient
extends StaticBody3D

signal collected(definition_id: StringName)

@export var definition_id: StringName
@onready var interactable: InteractableComponent = %InteractableComponent


func _ready() -> void:
	var definition := ContentDB.get_definition(definition_id)
	if definition != null:
		interactable.object_name = definition.display_name
		interactable.inspection_description = definition.description
	interactable.interaction_completed.connect(_on_interaction_completed)


func _on_interaction_completed(actor: Node, _action: StringName) -> void:
	if actor == null:
		return
	var inventory := actor.find_child("InventoryComponent", true, false) as InventoryComponent
	if inventory == null:
		return
	var item := ItemInstance.new(definition_id, 1.0)
	if inventory.add_item(item):
		collected.emit(definition_id)
		queue_free()
