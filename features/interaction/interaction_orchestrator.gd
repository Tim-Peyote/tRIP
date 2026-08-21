class_name InteractionOrchestrator
extends RayCast3D

signal focus_changed(component: InteractableComponent)
signal prompt_changed(text: String)
signal context_changed(context: Dictionary)
signal hold_progress_changed(progress: float)
signal inspection_requested(title: String, description: String)
signal inspection_definition_requested(definition_id: StringName, title: String, description: String)

var actor: Node
var focused: InteractableComponent
var _active: InteractableComponent
var _hold_elapsed: float = 0.0
var grabbed_body: RigidBody3D
var _focused_body: RigidBody3D
var _grab_distance: float = 1.8
var _rotating_body: bool = false
var _stored_linear_damp: float = 0.0
var _stored_angular_damp: float = 0.0

const MAX_GRAB_MASS := 32.0
const MIN_GRAB_DISTANCE := 0.75
const MAX_GRAB_DISTANCE := 3.0
const GRAB_STIFFNESS := 58.0
const GRAB_DAMPING := 12.0
const MAX_GRAB_FORCE := 1450.0


func _ready() -> void:
	enabled = true
	set_physics_process(true)


func _process(delta: float) -> void:
	_update_focus()
	_update_interaction(delta)


func _physics_process(_delta: float) -> void:
	_update_grabbed_body()


func _unhandled_input(event: InputEvent) -> void:
	if grabbed_body == null:
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			_grab_distance = clampf(_grab_distance + 0.18, MIN_GRAB_DISTANCE, MAX_GRAB_DISTANCE)
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			_grab_distance = clampf(_grab_distance - 0.18, MIN_GRAB_DISTANCE, MAX_GRAB_DISTANCE)
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and Input.is_action_pressed(&"alternate"):
		var motion := event as InputEventMouseMotion
		var torque := global_basis.y * -motion.relative.x + global_basis.x * -motion.relative.y
		grabbed_body.apply_torque(torque * maxf(grabbed_body.mass, 0.5) * 0.32)
		_rotating_body = true
		get_viewport().set_input_as_handled()


func _update_focus() -> void:
	if grabbed_body != null:
		return
	force_raycast_update()
	var next_focus: InteractableComponent
	var next_body: RigidBody3D
	if is_colliding():
		var collider := get_collider() as Node
		next_focus = _find_component(collider)
		if next_focus == null:
			next_body = _find_rigid_body(collider)
	if next_focus == focused and next_body == _focused_body:
		return
	_cancel_active()
	focused = next_focus
	_focused_body = next_body
	focus_changed.emit(focused)
	_emit_context()


func _update_interaction(delta: float) -> void:
	_rotating_body = grabbed_body != null and Input.is_action_pressed(&"alternate")
	if grabbed_body != null:
		if Input.is_action_just_pressed(&"inspect"):
			_throw_grabbed_body()
		elif Input.is_action_just_released(&"interact"):
			_release_grabbed_body()
		return
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
	elif Input.is_action_just_pressed(&"interact") and _focused_body != null:
		_begin_grab(_focused_body)
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


func _find_rigid_body(collider: Node) -> RigidBody3D:
	var current := collider
	for _depth in 4:
		if current == null:
			break
		if current is RigidBody3D:
			var body := current as RigidBody3D
			if not body.freeze and body.mass <= MAX_GRAB_MASS:
				return body
		current = current.get_parent()
	return null


func _emit_context() -> void:
	if focused != null:
		var context := focused.get_context(actor)
		prompt_changed.emit(String(context.get("action", "")))
		context_changed.emit(context)
		return
	if _focused_body != null:
		var title := String(_focused_body.get_meta(&"interaction_name", _humanize_name(_focused_body.name)))
		var context := {
			"key": "LMB",
			"title": title,
			"action": "Удерживать · взять  |  ПКМ · вращать  |  F · бросить",
			"physical": true,
			"mass": _focused_body.mass,
		}
		prompt_changed.emit(String(context.action))
		context_changed.emit(context)
		return
	prompt_changed.emit("")
	context_changed.emit({})


func _begin_grab(body: RigidBody3D) -> void:
	grabbed_body = body
	_focused_body = body
	_grab_distance = clampf(global_position.distance_to(body.global_position), MIN_GRAB_DISTANCE, MAX_GRAB_DISTANCE)
	_stored_linear_damp = body.linear_damp
	_stored_angular_damp = body.angular_damp
	body.linear_damp = 7.0
	body.angular_damp = 6.0
	body.sleeping = false
	_emit_context()


func _update_grabbed_body() -> void:
	if not is_instance_valid(grabbed_body):
		grabbed_body = null
		_emit_context()
		return
	var target := global_position + -global_basis.z * _grab_distance
	var displacement := target - grabbed_body.global_position
	if displacement.length() > 4.5:
		_release_grabbed_body()
		return
	var force := displacement * GRAB_STIFFNESS * maxf(grabbed_body.mass, 0.4)
	force -= grabbed_body.linear_velocity * GRAB_DAMPING * maxf(grabbed_body.mass, 0.4)
	grabbed_body.apply_central_force(force.limit_length(MAX_GRAB_FORCE))


func _release_grabbed_body() -> void:
	if grabbed_body == null:
		return
	grabbed_body.linear_damp = _stored_linear_damp
	grabbed_body.angular_damp = _stored_angular_damp
	grabbed_body = null
	_rotating_body = false
	force_raycast_update()
	_focused_body = _find_rigid_body(get_collider() as Node) if is_colliding() else null
	_emit_context()


func _throw_grabbed_body() -> void:
	var body := grabbed_body
	if body == null:
		return
	_release_grabbed_body()
	body.apply_central_impulse(-global_basis.z * clampf(8.0 / maxf(body.mass, 0.5), 2.2, 9.0))


func is_rotating_held_body() -> bool:
	return _rotating_body


func is_holding_body() -> bool:
	return grabbed_body != null


func _humanize_name(value: String) -> String:
	return value.replace("_", " ").capitalize()
