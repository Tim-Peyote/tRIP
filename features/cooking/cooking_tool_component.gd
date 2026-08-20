class_name CookingToolComponent
extends Node

@export var operation: StringName
@export var ingredient_id: StringName = &"ingredient.mooncap"
@export var ingredient_tags: Array[StringName] = []
@export_range(0.0, 100.0, 0.01) var amount: float = 1.0
@export_range(-50.0, 300.0, 0.1, "suffix:°C") var temperature: float = 20.0
@export_range(0.0, 3600.0, 0.1, "suffix:s") var duration: float = 1.0
@export var required_item_id: StringName

var orchestrator: CookingOrchestrator
@onready var interactable: InteractableComponent = get_parent().get_node("InteractableComponent") as InteractableComponent


func _ready() -> void:
	interactable.interaction_completed.connect(_on_interaction_completed)


func setup(p_orchestrator: CookingOrchestrator) -> void:
	orchestrator = p_orchestrator


func _on_interaction_completed(actor: Node, _action: StringName) -> void:
	if orchestrator == null:
		push_error("CookingToolComponent '%s' has no CookingOrchestrator." % get_path())
		return
	orchestrator.perform_action(
		actor,
		operation,
		ingredient_id,
		ingredient_tags,
		amount,
		temperature,
		duration,
		required_item_id
	)

