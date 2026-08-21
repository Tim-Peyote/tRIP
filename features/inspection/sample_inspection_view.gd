class_name SampleInspectionView
extends Control

signal closed
signal clue_found(definition_id: StringName, clue_id: StringName, total_clues: int)
signal inspection_completed(definition_id: StringName)

@onready var viewport_container: SubViewportContainer = %ViewportContainer
@onready var model_root: Node3D = %ModelRoot
@onready var camera: Camera3D = %InspectionCamera

var session := InspectionSession.new()
var _model: Node3D
var _dragging: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = TripUITheme.build()
	$InfoPanel.add_theme_stylebox_override("panel", TripUITheme.make_modal_panel(Color("92b8a2")))
	$InfoPanel/Margin/Layout/FindingPanel.add_theme_stylebox_override("panel", TripUITheme.make_content_panel(TripUITheme.EMBER, 0.84))
	viewport_container.gui_input.connect(_on_viewport_input)
	session.clue_discovered.connect(_on_clue_discovered)
	session.completed.connect(_on_session_completed)
	visible = false


func open_definition(definition_id: StringName) -> bool:
	var definition := ContentDB.get_definition(definition_id) as IngredientDefinition
	if definition == null or definition.inspect_scene == null:
		return false
	_clear_model()
	_model = definition.inspect_scene.instantiate() as Node3D
	model_root.add_child(_model)
	%Title.text = definition.display_name
	%Description.text = definition.description
	session.setup(definition)
	_apply_transform()
	_update_clue_list()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return true


func close() -> void:
	if not visible:
		return
	visible = false
	_dragging = false
	closed.emit()


func rotate_sample(yaw_delta: float, pitch_delta: float) -> void:
	session.rotate(yaw_delta, pitch_delta)
	_apply_transform()


func set_zoom(value: float) -> void:
	session.set_zoom(value)
	camera.position.z = lerpf(-3.6, -2.55, session.zoom)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"inspect") or event.is_action_pressed(&"interact") or event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"move_left"):
		rotate_sample(-18.0, 0.0)
	elif event.is_action_pressed(&"move_right"):
		rotate_sample(18.0, 0.0)


func _on_viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(session.zoom + 0.12)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(session.zoom - 0.12)
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		rotate_sample(motion.relative.x * 0.55, motion.relative.y * 0.4)


func _apply_transform() -> void:
	model_root.rotation_degrees = Vector3(session.pitch, session.yaw, 0.0)


func _on_clue_discovered(clue: InspectionClueDefinition) -> void:
	_update_clue_list()
	%FindingTitle.text = clue.label
	%FindingDescription.text = clue.description
	%FindingPanel.visible = true
	clue_found.emit(session.definition.id, clue.id, session.definition.inspection_clues.size())


func _on_session_completed() -> void:
	%CompletionLabel.visible = true
	inspection_completed.emit(session.definition.id)


func _update_clue_list() -> void:
	if session.definition == null:
		return
	var lines := PackedStringArray()
	for clue: InspectionClueDefinition in session.definition.inspection_clues:
		lines.append("✓ %s" % clue.label if session.discovered.has(clue.id) else "? Неизученный признак")
	%ClueList.text = "\n".join(lines)
	%Progress.text = "%d / %d признаков" % [session.discovered.size(), session.definition.inspection_clues.size()]
	%FindingPanel.visible = false
	%CompletionLabel.visible = session.is_complete()


func _clear_model() -> void:
	if _model != null:
		_model.queue_free()
	_model = null
