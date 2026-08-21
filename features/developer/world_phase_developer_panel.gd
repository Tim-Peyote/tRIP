class_name WorldPhaseDeveloperPanel
extends Node

var _orchestrator: WorldPhaseOrchestrator
var _terrain: ExpeditionTerrain
var _canvas: CanvasLayer
var _panel: PanelContainer
var _status: Label
var _seed_label: Label
var _seed: int = 117
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED


func setup(orchestrator: WorldPhaseOrchestrator, terrain: ExpeditionTerrain) -> void:
	_orchestrator = orchestrator
	_terrain = terrain
	_build_ui()
	_orchestrator.phase_changed.connect(_on_phase_changed)
	_update_status()


func set_panel_visible(value: bool) -> void:
	if _panel != null:
		_panel.visible = value
		if value:
			_previous_mouse_mode = Input.mouse_mode
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = _previous_mouse_mode


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_F10:
		set_panel_visible(not _panel.visible)
		get_viewport().set_input_as_handled()
		return
	if not _panel.visible:
		return
	if key.keycode == KEY_PAGEUP:
		_cycle_phase(-1)
	elif key.keycode == KEY_PAGEDOWN:
		_cycle_phase(1)
	elif key.keycode == KEY_R:
		_randomize_seed()
	elif key.keycode == KEY_BACKSPACE:
		_orchestrator.clear_developer_override()
	else:
		return
	get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "WorldPhaseDeveloperCanvas"
	_canvas.layer = 90
	add_child(_canvas)
	_panel = PanelContainer.new()
	_panel.name = "WorldPhaseDeveloperPanel"
	_panel.visible = false
	_panel.position = Vector2(24, 92)
	_panel.custom_minimum_size = Vector2(390, 0)
	_canvas.add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	var title := Label.new()
	title.text = "РЕЖИМ РАЗРАБОТЧИКА · МИРЫ СОЗНАНИЯ"
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_seed_label = Label.new()
	column.add_child(_seed_label)
	var definitions := _orchestrator.get_definitions()
	for definition: WorldPhaseDefinition in definitions:
		var button := Button.new()
		button.text = "%d · %s" % [definition.order, definition.display_name]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_orchestrator.set_developer_phase.bind(definition.id))
		column.add_child(button)
	var help := Label.new()
	help.text = "PgUp/PgDn — мир   R — новый seed   Backspace — снять симуляцию   F10 — закрыть"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.modulate = Color(0.68, 0.76, 0.62)
	column.add_child(help)


func _cycle_phase(direction: int) -> void:
	var definitions := _orchestrator.get_definitions()
	if definitions.is_empty():
		return
	var current_index := 0
	var current := _orchestrator.get_current()
	for index in definitions.size():
		if definitions[index] == current:
			current_index = index
			break
	current_index = posmod(current_index + direction, definitions.size())
	_orchestrator.set_developer_phase(definitions[current_index].id)


func _randomize_seed() -> void:
	_seed = randi_range(1, 999999)
	_terrain.set_run_seed(_seed)
	_update_status()


func _on_phase_changed(_definition: WorldPhaseDefinition, _developer_override: bool) -> void:
	_update_status()


func _update_status() -> void:
	if _orchestrator == null or _status == null:
		return
	var definition := _orchestrator.get_current()
	if definition == null:
		return
	_status.text = "%s\n%s\nРецепт стабилизации: %s" % [definition.display_name, definition.description, definition.stabilizing_recipe_id]
	_seed_label.text = "Seed: %d · чанков загружено: %d" % [_seed, _terrain.get_loaded_chunk_count()]
