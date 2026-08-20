class_name NarrativeClue
extends StaticBody3D

signal discovered(clue_id: StringName, title: String, text: String)

@export var clue_id: StringName
@export var title: String = "След"
@export_multiline var text: String
@export var requires_spore_vision: bool = false
@onready var interactable: InteractableComponent = %InteractableComponent

var _spore_vision_active: bool = false
var _was_discovered: bool = false


func _ready() -> void:
	interactable.object_name = title
	interactable.inspection_description = text
	interactable.interaction_completed.connect(_on_interaction_completed)


func set_spore_vision_active(value: bool) -> void:
	_spore_vision_active = value


func get_interaction_prompt(_actor: Node) -> String:
	if requires_spore_vision and not _spore_vision_active:
		return "На коре есть след, но взгляд соскальзывает"
	return "Исследовать: %s" % title


func can_receive_interaction(_actor: Node) -> bool:
	return not requires_spore_vision or _spore_vision_active


func _on_interaction_completed(_actor: Node, _action: StringName) -> void:
	if _was_discovered or (requires_spore_vision and not _spore_vision_active):
		return
	_was_discovered = true
	discovered.emit(clue_id, title, text)

