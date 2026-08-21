class_name NarrativeClue
extends StaticBody3D

signal discovered(clue_id: StringName, title: String, text: String)

@export var clue_id: StringName
@export var title: String = "След"
@export_multiline var text: String
@export var requires_spore_vision: bool = false
@export var required_world_state: StringName
@onready var interactable: InteractableComponent = %InteractableComponent

var _spore_vision_active: bool = false
var _was_discovered: bool = false
var _world_state: StringName


func _ready() -> void:
	interactable.object_name = title
	interactable.inspection_description = text
	interactable.interaction_completed.connect(_on_interaction_completed)
	_refresh_availability()


func set_spore_vision_active(value: bool) -> void:
	_spore_vision_active = value
	_refresh_availability()


func set_world_state(value: StringName) -> void:
	_world_state = value
	_refresh_availability()


func get_interaction_prompt(_actor: Node) -> String:
	if not _requirements_met():
		return "На коре есть след, но взгляд соскальзывает"
	return "Исследовать: %s" % title


func can_receive_interaction(_actor: Node) -> bool:
	return _requirements_met()


func _on_interaction_completed(_actor: Node, _action: StringName) -> void:
	if _was_discovered or not _requirements_met():
		return
	_was_discovered = true
	discovered.emit(clue_id, title, text)


func _requirements_met() -> bool:
	var vision_ready := not requires_spore_vision or _spore_vision_active
	var state_ready := required_world_state == &"" or required_world_state == _world_state
	return vision_ready and state_ready


func _refresh_availability() -> void:
	var available := _requirements_met()
	if requires_spore_vision or required_world_state != &"":
		visible = available
		collision_layer = 4 if available else 0
	interactable.enabled = available
