class_name InteractionOrchestrator
extends RayCast3D

signal focus_changed(component: InteractableComponent)
signal prompt_changed(text: String)
signal hold_progress_changed(progress: float)
signal inspection_requested(title: String, description: String)
signal inspection_definition_requested(definition_id: StringName, title: String, description: String)

var actor: Node
var focused: InteractableComponent
var _active: InteractableComponent
var _hold_elapsed: float = 0.0


func _ready() -> void:
	enabled = true


func _process(delta: float) -> void:
	_update_focus()
	_update_interaction(delta)


func _update_focus() -> void:
	force_raycast_update()
	var next_focus: InteractableComponent
	if is_colliding():
		next_focus = _find_component(get_collider() as Node)
	if next_focus == focused:
		return
	_cancel_active()
	focused = next_focus
	focus_changed.emit(focused)
	prompt_changed.emit(focused.get_prompt(actor) if focused != null else "")


func _update_interaction(delta: float) -> void:
	if Input.is_action_just_pressed(&"alternate") and focused != null:
		focused.request_alternative(actor)
		prompt_changed.emit(focused.get_prompt(actor))
	if Input.is_action_just_pressed(&"inspect") and focused != null:
		var inspection := focused.request_inspection(actor)
		var definition_id := StringName(inspection.get("definition_id", &""))
		var title := String(inspection.get("title", ""))
		var description := String(inspection.get("description", ""))
		if definition_id != &"":
			inspection_definition_requested.emit(definition_id, title, description)
		else:
			inspection_requested.emit(title, description)
	if Input.is_action_just_pressed(&"interact") and focused != null:
		if focused.begin_interaction(actor):
			_active = focused
			_hold_elapsed = 0.0
			if _active.hold_duration <= 0.0:
				_complete_active()
	if _active == null:
		return
	if Input.is_action_just_released(&"interact"):
		_cancel_active()
		return
	if Input.is_action_pressed(&"interact"):
		_hold_elapsed += delta
		var progress := clampf(_hold_elapsed / maxf(_active.hold_duration, 0.001), 0.0, 1.0)
		hold_progress_changed.emit(progress)
		if progress >= 1.0:
			_complete_active()


func _complete_active() -> void:
	if _active == null:
		return
	var completed := _active
	_active = null
	_hold_elapsed = 0.0
	hold_progress_changed.emit(0.0)
	completed.complete_interaction(actor)


func _cancel_active() -> void:
	if _active != null:
		_active.cancel_interaction(actor)
	_active = null
	_hold_elapsed = 0.0
	hold_progress_changed.emit(0.0)


func _find_component(collider: Node) -> InteractableComponent:
	var current := collider
	for _depth in 4:
		if current == null:
			break
		if current is InteractableComponent:
			return current as InteractableComponent
		for child: Node in current.get_children():
			if child is InteractableComponent:
				return child as InteractableComponent
		current = current.get_parent()
	return null
