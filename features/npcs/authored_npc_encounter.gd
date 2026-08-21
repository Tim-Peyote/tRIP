class_name AuthoredNPCEncounter
extends StaticBody3D

signal encounter_completed(clue_id: StringName, title: String, text: String)

@export var definition: NPCArchetypeDefinition
@export var required_clue_id: StringName
@export var result_clue_id: StringName
@export var encounter_title: String = "Встреча"
@export_multiline var encounter_text: String
@export var idle_animation: StringName = &"Human Armature|Idle"
@export var action_animation: StringName = &"Human Armature|Working"

@onready var interactable: InteractableComponent = %InteractableComponent

var _loop: GameLoopOrchestrator
var _animation_player: AnimationPlayer
var _completed: bool = false


func _ready() -> void:
	_animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	var material_driver := get_node_or_null("EchoMaterialDriver") as MeshInstance3D
	if material_driver != null and material_driver.material_override != null:
		for node: Node in $Rig.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			mesh.material_override = material_driver.material_override
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	interactable.interaction_completed.connect(_on_interaction_completed)
	_apply_definition()
	_play(idle_animation, 0.92)
	_refresh_availability()


func setup(loop: GameLoopOrchestrator) -> void:
	_loop = loop
	if not loop.stage_changed.is_connected(_on_loop_state_changed):
		loop.stage_changed.connect(_on_loop_state_changed)
	_refresh_availability()


func get_interaction_prompt(_actor: Node) -> String:
	if not _requirements_met():
		return "Силуэт распадается, когда пытаешься на нём сосредоточиться"
	if _completed:
		return "Сверить остаточный контур Ильи"
	return "Окликнуть совпавшее отражение"


func can_receive_interaction(_actor: Node) -> bool:
	return _requirements_met()


func get_inspection_data() -> Dictionary:
	return {
		"definition_id": definition.id if definition != null else &"",
		"title": definition.display_name if definition != null else encounter_title,
		"description": encounter_text,
	}


func is_encounter_available() -> bool:
	return _requirements_met()


func _apply_definition() -> void:
	if definition == null:
		return
	interactable.object_name = definition.display_name
	interactable.inspection_description = definition.description


func _requirements_met() -> bool:
	if required_clue_id == &"":
		return true
	return _loop != null and _loop.mycologist_clues.has(required_clue_id)


func _refresh_availability() -> void:
	var available := _requirements_met()
	visible = available
	collision_layer = 4 if available else 0
	interactable.enabled = available
	set_process(available)


func _on_loop_state_changed(_stage: int, _objective_text: String) -> void:
	_refresh_availability()


func _on_interaction_completed(_actor: Node, _action: StringName) -> void:
	if not _requirements_met():
		return
	_play(action_animation, 0.82)
	if _completed:
		return
	_completed = true
	encounter_completed.emit(result_clue_id, encounter_title, encounter_text)
	get_tree().create_timer(2.3).timeout.connect(func() -> void: _play(idle_animation, 0.88))


func _play(animation_name: StringName, speed: float) -> void:
	if _animation_player == null:
		return
	var resolved := _resolve_animation(animation_name)
	if resolved == &"":
		return
	_animation_player.play(resolved, 0.22, speed)


func _resolve_animation(requested: StringName) -> StringName:
	if _animation_player.has_animation(requested):
		return requested
	var suffix := String(requested).get_slice("|", 1)
	for available: StringName in _animation_player.get_animation_list():
		if String(available).get_slice("|", 1) == suffix:
			return available
	return &""
