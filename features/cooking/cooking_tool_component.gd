class_name CookingToolComponent
extends Node

@export var operation: StringName
@export var ingredient_id: StringName = &"ingredient.mooncap"
@export var ingredient_tags: Array[StringName] = []
@export_range(0.0, 100.0, 0.01) var amount: float = 1.0
@export_range(-50.0, 300.0, 0.1, "suffix:°C") var temperature: float = 20.0
@export_range(0.0, 3600.0, 0.1, "suffix:s") var duration: float = 1.0
@export var required_item_id: StringName
@export var candidate_ingredient_ids: Array[StringName] = []
@export var animated_node_path: NodePath
@export var action_rotation_degrees: Vector3 = Vector3.ZERO

var orchestrator: CookingOrchestrator
@onready var interactable: InteractableComponent = get_parent().get_node("InteractableComponent") as InteractableComponent
var _animated_node: Node3D
var _animated_rest_rotation: Vector3
var _action_tween: Tween


func _ready() -> void:
	interactable.interaction_completed.connect(_on_interaction_completed)
	if not animated_node_path.is_empty():
		_animated_node = get_parent().get_node_or_null(animated_node_path) as Node3D
		if _animated_node != null:
			_animated_rest_rotation = _animated_node.rotation


func setup(p_orchestrator: CookingOrchestrator) -> void:
	orchestrator = p_orchestrator


func _on_interaction_completed(actor: Node, _action: StringName) -> void:
	if orchestrator == null:
		push_error("CookingToolComponent '%s' has no CookingOrchestrator." % get_path())
		return
	var selected_ingredient_id := ingredient_id
	var selected_required_id := required_item_id
	var selected_tags := ingredient_tags.duplicate()
	if not orchestrator.process.events.is_empty():
		var prepared := orchestrator.process.events[0]
		selected_ingredient_id = prepared.ingredient_id
		selected_required_id = &""
		selected_tags.assign(prepared.ingredient_tags)
	else:
		var inventory := actor.find_child("InventoryComponent", true, false) as InventoryComponent
		var selected := inventory.get_item(orchestrator.selected_instance_id) if inventory != null else null
		if selected == null:
			orchestrator.action_rejected.emit("Открой сумку [I], выбери образец и нажми «Для лаборатории».")
			return
		selected_ingredient_id = selected.definition_id
		selected_required_id = selected.definition_id
		var definition := ContentDB.get_definition(selected.definition_id) as IngredientDefinition
		if definition != null: selected_tags.assign(definition.tags)
	if orchestrator.perform_action(
		actor,
		operation,
		selected_ingredient_id,
		selected_tags,
		amount,
		temperature,
		duration,
		selected_required_id
	):
		_play_tool_action()


func _play_tool_action() -> void:
	if _animated_node == null or action_rotation_degrees.is_zero_approx():
		return
	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()
	_action_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_action_tween.tween_property(_animated_node, "rotation", _animated_rest_rotation + action_rotation_degrees * PI / 180.0, 0.2)
	_action_tween.tween_property(_animated_node, "rotation", _animated_rest_rotation, 0.28)
