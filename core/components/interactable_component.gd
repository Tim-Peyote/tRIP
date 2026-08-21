class_name InteractableComponent
extends Node

signal interaction_started(actor: Node, action: StringName)
signal interaction_completed(actor: Node, action: StringName)
signal interaction_cancelled(actor: Node, action: StringName)
signal alternative_requested(actor: Node)
signal inspection_requested(actor: Node)

@export var object_name: String = "объект"
@export var primary_action: StringName = &"interact"
@export var primary_verb: String = "Взаимодействовать"
@export_range(0.0, 10.0, 0.05, "suffix:s") var hold_duration: float = 0.0
@export var enabled: bool = true
@export_multiline var inspection_description: String
@export_enum("use", "collect", "examine", "operate", "ritual") var affordance: String = "use"
@export var input_hint: String = "E"


func get_prompt(actor: Node) -> String:
	if not enabled:
		return ""
	if get_parent().has_method("get_interaction_prompt"):
		return String(get_parent().call("get_interaction_prompt", actor))
	return "%s: %s" % [primary_verb, object_name]


func get_context(actor: Node) -> Dictionary:
	return {
		"key": input_hint,
		"title": object_name,
		"action": get_prompt(actor),
		"affordance": affordance,
		"hold": hold_duration > 0.0,
		"physical": false,
	}


func can_interact(actor: Node, action: StringName = primary_action) -> bool:
	if not enabled or action != primary_action:
		return false
	if get_parent().has_method("can_receive_interaction"):
		return bool(get_parent().call("can_receive_interaction", actor))
	return true


func get_inspection() -> Dictionary:
	if get_parent().has_method("get_inspection_data"):
		return get_parent().call("get_inspection_data") as Dictionary
	return {
		"title": object_name,
		"description": inspection_description,
	}


func request_inspection(actor: Node) -> Dictionary:
	inspection_requested.emit(actor)
	return get_inspection()


func request_alternative(actor: Node) -> void:
	alternative_requested.emit(actor)


func begin_interaction(actor: Node, action: StringName = primary_action) -> bool:
	if not can_interact(actor, action):
		return false
	interaction_started.emit(actor, action)
	return true


func complete_interaction(actor: Node, action: StringName = primary_action) -> void:
	interaction_completed.emit(actor, action)


func cancel_interaction(actor: Node, action: StringName = primary_action) -> void:
	interaction_cancelled.emit(actor, action)
