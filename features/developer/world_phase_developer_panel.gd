class_name WorldPhaseDeveloperPanel
extends Node

var _orchestrator: WorldPhaseOrchestrator
var _terrain: ExpeditionTerrain
var _progression: WorldProgressionOrchestrator
var _hazard: BiomeHazardOrchestrator
var _laboratory: RoadLaboratoryOrchestrator
var _player: FirstPersonController
var _clock: ExpeditionClock
var _persistence: SessionPersistenceOrchestrator
var _population: BiomePopulationOrchestrator
var _weather: WeatherOrchestrator
var _canvas: CanvasLayer
var _panel: Control
var _status: Label
var _seed_label: Label
var _seed: int = 117
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _status_elapsed: float = 0.0
var _tools: VBoxContainer
var _responsive_grids: Array[GridContainer] = []
var _phase_buttons: Dictionary[StringName, Button] = {}
var _weather_buttons: Dictionary[int, Button] = {}
var _header: HBoxContainer
var _status_panel: PanelContainer
var _scroll: DeveloperToolsScroll
var _help: Label


func setup(
	orchestrator: WorldPhaseOrchestrator,
	terrain: ExpeditionTerrain,
	progression: WorldProgressionOrchestrator = null,
	hazard: BiomeHazardOrchestrator = null,
	laboratory: RoadLaboratoryOrchestrator = null,
	player: FirstPersonController = null,
	clock: ExpeditionClock = null,
	persistence: SessionPersistenceOrchestrator = null,
	population: BiomePopulationOrchestrator = null
) -> void:
	_orchestrator = orchestrator
	_terrain = terrain
	_progression = progression
	_hazard = hazard
	_laboratory = laboratory
	_player = player
	_clock = clock
	_persistence = persistence
	_population = population
	_build_ui()
	_orchestrator.phase_changed.connect(_on_phase_changed)
	if _laboratory != null:
		_laboratory.ritual_state_changed.connect(func(_unlocked: bool, _manifested: bool) -> void: _update_status())
	_update_status()
	set_process(true)


func set_panel_visible(value: bool) -> void:
	if _panel != null:
		_panel.visible = value
		if value:
			_previous_mouse_mode = Input.mouse_mode
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = _previous_mouse_mode
	if _player != null:
		_player.set_gameplay_enabled(not value)
		_player.set_viewmodel_interface_hidden(value)
		_player.interactor.set_process(not value)
	_apply_responsive_layout()
	_update_status()


func setup_weather(value: WeatherOrchestrator) -> void:
	_weather = value
	if _panel != null:
		_rebuild_weather_controls()


func is_panel_visible() -> bool:
	return _panel != null and _panel.visible


func _process(delta: float) -> void:
	if _panel == null or not _panel.visible:
		return
	_status_elapsed += delta
	if _status_elapsed >= 0.25:
		_status_elapsed = 0.0
		_update_status()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	var physical := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	if physical == KEY_F10:
		# TripMain owns opening so it can close inventory/map first. The panel keeps
		# a local close fallback because it is also instantiated by isolated QA scenes.
		if _panel.visible:
			set_panel_visible(false)
			get_viewport().set_input_as_handled()
		return
	if not _panel.visible:
		return
	if physical >= KEY_1 and physical <= KEY_8:
		_set_phase_by_index(int(physical - KEY_1))
		get_viewport().set_input_as_handled()
		return
	if physical == KEY_PAGEUP:
		_cycle_phase(-1)
	elif physical == KEY_PAGEDOWN:
		_cycle_phase(1)
	elif physical == KEY_R:
		_randomize_seed()
	elif physical == KEY_BACKSPACE:
		_orchestrator.clear_developer_override()
	elif physical == KEY_ENTER and _progression != null:
		_progression.simulate_transition_formula()
	elif physical == KEY_P and _progression != null:
		_progression.simulate_nearest_mystery_event()
	elif physical == KEY_H and _hazard != null:
		_hazard.force_active()
	elif physical == KEY_DELETE and _hazard != null:
		_hazard.developer_clear()
	elif physical == KEY_M and _laboratory != null:
		_laboratory.developer_toggle(not key.shift_pressed)
	elif physical == KEY_T:
		_teleport_route_ahead()
	elif physical == KEY_O:
		_teleport_to_nearest(&"poi")
	elif physical == KEY_C:
		_teleport_to_nearest(&"composition")
	elif physical == KEY_I:
		_add_current_biome_sample()
	elif physical == KEY_Y:
		_cycle_time()
	elif physical == KEY_K and _population != null:
		_population.developer_respawn()
	elif physical == KEY_N and _population != null:
		_population.developer_cycle_density()
	elif physical == KEY_W and _weather != null:
		_weather.developer_cycle()
	elif physical == KEY_B:
		_teleport_to_physics_lab()
	else:
		return
	get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "WorldPhaseDeveloperCanvas"
	_canvas.layer = 90
	add_child(_canvas)
	_panel = Control.new()
	_panel.name = "WorldPhaseDeveloperPanel"
	_panel.visible = false
	_panel.theme = TripUITheme.build()
	_canvas.add_child(_panel)
	var background := PanelContainer.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.add_theme_stylebox_override("panel", TripUITheme.make_modal_panel(Color("a9c86d")))
	_panel.add_child(background)
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 12)
	_panel.add_child(_header)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(title_stack)
	var title := Label.new()
	title.text = "ПУЛЬТ РАЗРАБОТЧИКА"
	title.add_theme_font_size_override("font_size", 22)
	title_stack.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "МИР · СЦЕНАРИИ · ФИЗИОЛОГИЯ · ПОГОДА"
	subtitle.modulate = Color(0.62, 0.71, 0.59)
	subtitle.add_theme_font_size_override("font_size", 11)
	title_stack.add_child(subtitle)
	var close_button := Button.new()
	close_button.text = "F10  ЗАКРЫТЬ"
	close_button.custom_minimum_size = Vector2(118, 38)
	close_button.pressed.connect(set_panel_visible.bind(false))
	_header.add_child(close_button)
	_status_panel = PanelContainer.new()
	_status_panel.clip_contents = true
	_status_panel.add_theme_stylebox_override("panel", TripUITheme.make_glass_panel(Color("9fbd72"), 0.74))
	_panel.add_child(_status_panel)
	var status_margin := MarginContainer.new()
	status_margin.add_theme_constant_override("margin_left", 14)
	status_margin.add_theme_constant_override("margin_right", 14)
	status_margin.add_theme_constant_override("margin_top", 10)
	status_margin.add_theme_constant_override("margin_bottom", 10)
	_status_panel.add_child(status_margin)
	var status_column := VBoxContainer.new()
	status_column.add_theme_constant_override("separation", 4)
	status_margin.add_child(status_column)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 12)
	status_column.add_child(_status)
	_seed_label = Label.new()
	_seed_label.modulate = Color(0.67, 0.76, 0.62)
	_seed_label.add_theme_font_size_override("font_size", 11)
	status_column.add_child(_seed_label)
	_scroll = DeveloperToolsScroll.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	_tools = VBoxContainer.new()
	_tools.name = "DeveloperTools"
	_tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tools.add_theme_constant_override("separation", 12)
	_scroll.add_child(_tools)
	var world_grid := _add_section("МИРЫ", "1–8 · отдельная генерация и разведка для каждого слоя")
	var definitions := _orchestrator.get_definitions()
	for definition: WorldPhaseDefinition in definitions:
		var button := Button.new()
		button.text = "%d · %s" % [definition.order + 1, definition.display_name]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 36)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.tooltip_text = String(definition.content_pack.landscape_statement) if definition.content_pack != null else definition.display_name
		button.pressed.connect(_orchestrator.set_developer_phase.bind(definition.id))
		world_grid.add_child(button)
		_phase_buttons[definition.id] = button
	var action_grid := _add_section("СЦЕНАРИИ И НАВИГАЦИЯ", "Переходы, события, лаборатория и точки проверки")
	if _progression != null:
		_add_action_button(action_grid, "ENTER  Принять формулу", _progression.simulate_transition_formula, &"transition_formula")
		_add_action_button(action_grid, "P  Решить ближайшее таинство", _progression.simulate_nearest_mystery_event, &"resolve_mystery")
	if _hazard != null:
		_add_action_button(action_grid, "H  Запустить явление", _hazard.force_active, &"hazard_start")
		_add_action_button(action_grid, "DEL  Очистить явление", _hazard.developer_clear, &"hazard_clear")
	if _laboratory != null:
		_add_action_button(action_grid, "M  Лаборатория с метаморфозой", _toggle_laboratory.bind(true), &"laboratory_animated")
		_add_action_button(action_grid, "SHIFT+M  Лаборатория мгновенно", _toggle_laboratory.bind(false), &"laboratory_instant")
	_add_action_button(action_grid, "T  Вперёд по маршруту +90 м", _teleport_route_ahead, &"teleport_route")
	_add_action_button(action_grid, "O  К ближайшему таинству", _teleport_to_nearest.bind(&"poi"), &"teleport_poi")
	_add_action_button(action_grid, "C  К экокомпозиции", _teleport_to_nearest.bind(&"composition"), &"teleport_composition")
	_add_action_button(action_grid, "B  Физический стенд", _teleport_to_physics_lab, &"teleport_physics")
	_add_action_button(action_grid, "I  Выдать образец мира", _add_current_biome_sample, &"grant_sample")
	if _clock != null:
		_add_action_button(action_grid, "Y  Следующее время суток", _cycle_time, &"cycle_time")
	if _persistence != null:
		_add_action_button(action_grid, "Сохранить состояние сейчас", _persistence.save_now.bind(&"developer_manual"), &"save")
	if _population != null:
		_add_action_button(action_grid, "K  Переселить живность", _population.developer_respawn, &"fauna_respawn")
		_add_action_button(action_grid, "N  Плотность фауны", _population.developer_cycle_density, &"fauna_density")
	_add_action_button(action_grid, "R  Новый seed генерации", _randomize_seed, &"randomize_seed")
	var body_grid := _add_section("СОСТОЯНИЕ ПЕРСОНАЖА", "Быстрая проверка HUD, урона и побочных эффектов")
	if _player != null and _player.vitals != null:
		_add_action_button(body_grid, "Восстановить показатели", _player.vitals.developer_restore, &"body_restore")
		_add_action_button(body_grid, "Переохлаждение", _player.vitals.developer_set_condition.bind(&"cold"), &"body_cold")
		_add_action_button(body_grid, "Замерзание", _player.vitals.developer_set_condition.bind(&"freezing"), &"body_freezing")
		_add_action_button(body_grid, "Отравление", _player.vitals.developer_set_condition.bind(&"toxic"), &"body_toxic")
		_add_action_button(body_grid, "Споровое заражение", _player.vitals.developer_set_condition.bind(&"spores"), &"body_spores")
		_add_action_button(body_grid, "Истощение", _player.vitals.developer_set_condition.bind(&"exhausted"), &"body_exhausted")
	var system_grid := _add_section("СИСТЕМА", "Возврат к сюжетному состоянию и диагностика")
	_add_action_button(system_grid, "BACKSPACE  Вернуть сюжетный мир", _orchestrator.clear_developer_override, &"clear_override")
	_help = Label.new()
	_help.text = "PGUP / PGDN  соседний мир    ·    1–8  прямой выбор    ·    F10  закрыть"
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.modulate = Color(0.68, 0.76, 0.62)
	_panel.add_child(_help)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func _rebuild_weather_controls() -> void:
	if _panel == null or _weather == null:
		return
	var existing := _panel.find_child("WeatherDeveloperControls", true, false)
	if existing != null:
		return
	if _tools == null:
		return
	var grid := _add_section("ПОГОДА", "W переключает по кругу · кнопки задают состояние напрямую", "WeatherDeveloperControls")
	for weather_state: int in WeatherOrchestrator.State.values():
		var button := _add_action_button(grid, ["Ясно", "Дождь", "Гроза", "Туман", "Снег"][weather_state], _weather.developer_set.bind(weather_state), StringName("weather_%d" % weather_state))
		button.toggle_mode = true
		_weather_buttons[weather_state] = button
	_apply_responsive_layout()


func _add_section(title_text: String, subtitle_text: String, node_name: String = "") -> GridContainer:
	var section := VBoxContainer.new()
	if not node_name.is_empty():
		section.name = node_name
	section.add_theme_constant_override("separation", 5)
	_tools.add_child(section)
	var title := Label.new()
	title.text = title_text
	title.modulate = Color(0.76, 0.86, 0.57)
	title.add_theme_font_size_override("font_size", 13)
	section.add_child(title)
	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.modulate = Color(0.55, 0.63, 0.54)
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(subtitle)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	section.add_child(grid)
	_responsive_grids.append(grid)
	return grid


func _add_action_button(parent: Control, text_value: String, callback: Callable, action_id: StringName = &"") -> Button:
	var button := Button.new()
	button.text = text_value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.set_meta(&"developer_action", action_id)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _apply_responsive_layout() -> void:
	if _panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 980.0
	var panel_width := minf(760.0, viewport_size.x - (24.0 if compact else 40.0))
	_panel.position = Vector2(12.0 if compact else 20.0, 12.0 if viewport_size.y < 800.0 else 20.0)
	_panel.size = Vector2(panel_width, viewport_size.y - _panel.position.y * 2.0)
	var inner_width := panel_width - 44.0
	_header.position = Vector2(22.0, 18.0)
	_header.size = Vector2(inner_width, 54.0)
	var status_height := 226.0 if viewport_size.y < 800.0 else 236.0
	_status_panel.position = Vector2(22.0, 78.0)
	_status_panel.size = Vector2(inner_width, status_height)
	var scroll_top := 78.0 + status_height + 14.0
	_scroll.position = Vector2(22.0, scroll_top)
	_scroll.size = Vector2(inner_width, maxf(150.0, _panel.size.y - scroll_top - 42.0))
	_help.position = Vector2(22.0, _panel.size.y - 28.0)
	_help.size = Vector2(inner_width, 22.0)
	for grid: GridContainer in _responsive_grids:
		grid.columns = 1 if panel_width < 610.0 else 2


func _set_phase_by_index(index: int) -> void:
	var definitions := _orchestrator.get_definitions()
	if index >= 0 and index < definitions.size():
		_orchestrator.set_developer_phase(definitions[index].id)


func _toggle_laboratory(animate: bool) -> void:
	if _laboratory != null:
		_laboratory.developer_toggle(animate)
	_update_status()


func _teleport_route_ahead() -> void:
	if _player == null:
		return
	var z := maxf(_player.global_position.z + 90.0, 105.0)
	var x := float(_terrain.call("_route_center_x", z))
	var position := Vector3(x, 0.0, z)
	position.y = _terrain.get_height_at_global(position) + 0.18
	_terrain.ensure_area_at(position)
	_player.global_position = position
	_player.velocity = Vector3.ZERO
	_update_status()


func _teleport_to_physics_lab() -> void:
	if _player == null:
		return
	var destination := Vector3(0.0, 0.0, 10.5)
	destination.y = _terrain.get_height_at_global(destination) + 0.18
	_player.global_position = destination
	_player.velocity = Vector3.ZERO
	_player.look_at(Vector3(0.0, destination.y + 0.8, 13.4), Vector3.UP)
	_update_status()


func _teleport_to_nearest(kind: StringName) -> void:
	if _player == null:
		return
	var target_position := Vector3.ZERO
	var found := false
	var nearest := INF
	var nodes: Array[Node]
	if kind == &"poi":
		nodes = _terrain.find_children("*", "WorldMysteryPOI", true, false)
	else:
		nodes = _terrain.find_children("EcologyComposition_*", "Node3D", true, false)
	for node: Node in nodes:
		var anchor := node as Node3D
		if kind == &"poi":
			var collision := node.find_child("MysteryCollision", true, false) as CollisionShape3D
			if collision != null:
				anchor = collision
		elif node.get_child_count() > 0 and node.get_child(0) is Node3D:
			anchor = node.get_child(0) as Node3D
		var distance := anchor.global_position.distance_to(_player.global_position)
		if distance < nearest:
			nearest = distance
			target_position = anchor.global_position
			found = true
	if not found:
		_teleport_route_ahead()
		return
	var offset := (_player.global_position - target_position)
	offset.y = 0.0
	if offset.length_squared() < 0.1:
		offset = Vector3(0, 0, 1)
	offset = offset.normalized() * 4.5
	var destination := target_position + offset
	destination.y = _terrain.get_height_at_global(destination) + 0.18
	_player.global_position = destination
	_player.velocity = Vector3.ZERO
	_player.look_at(Vector3(target_position.x, destination.y, target_position.z), Vector3.UP)
	_update_status()


func _add_current_biome_sample() -> void:
	if _player == null:
		return
	var definition := _orchestrator.get_current()
	if definition == null or definition.content_pack == null or definition.content_pack.local_ingredient_ids.is_empty():
		return
	_player.inventory.add_item(ItemInstance.new(definition.content_pack.local_ingredient_ids[0]))


func _cycle_time() -> void:
	if _clock == null:
		return
	var stops := [0.12, 0.65, 0.82]
	var next := 0.12
	for stop: float in stops:
		if stop > _clock.progress + 0.05:
			next = stop
			break
	_clock.set_progress(next)


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
	for phase_id: StringName in _phase_buttons:
		_phase_buttons[phase_id].set_pressed_no_signal(phase_id == definition.id)
	if _weather != null:
		for weather_state: int in _weather_buttons:
			_weather_buttons[weather_state].set_pressed_no_signal(weather_state == int(_weather.state))
	var contract := _progression.get_contract_text() if _progression != null else "Рецепт стабилизации: %s" % definition.stabilizing_recipe_id
	var laboratory_state := "закрыта"
	if _laboratory != null:
		laboratory_state = "метаморфоза" if _laboratory.is_metamorphosing() else ("проявлена" if _laboratory.manifested else ("готова" if _laboratory.unlocked else "не открыта"))
	var hazard_state := "—" if _hazard == null else "%d · %d%%" % [_hazard.state, roundi(_hazard.exposure * 100.0)]
	var player_state := "—" if _player == null else "x %.1f · y %.1f · z %.1f · %.1f м/с" % [_player.global_position.x, _player.global_position.y, _player.global_position.z, _player.get_planar_speed()]
	var fauna_state := "—" if _population == null else "%d · %s" % [_population.get_active_population_count(), ", ".join(_population.get_active_species_ids())]
	var weather_state := "—" if _weather == null else _weather.get_debug_text()
	var body_state := "—"
	if _player != null and _player.vitals != null:
		var body := _player.vitals.get_snapshot()
		body_state = "HP %.0f/%.0f · ST %.0f/%.0f · %.1f°C · вода %d%% · токсины %d%% · споры %d%%" % [
			body["health"], body["maximum_health"], body["stamina"], body["maximum_stamina"], body["core_temperature"],
			roundi(float(body["wetness"]) * 100.0), roundi(float(body["toxicity"]) * 100.0), roundi(float(body["spore_load"]) * 100.0),
		]
	_status.text = "%s · %s\n%s\nТело: %s\n%s\nФауна: %s\nПогода: %s" % [definition.display_name, contract, player_state, body_state, "Лаба: %s · явление: %s" % [laboratory_state, hazard_state], fauna_state, weather_state]
	var art_sample := _terrain.get_art_direction_sample(_player.global_position) if _terrain != null and _player != null else {}
	var art_state := "пятно %.2f · плодородие %.2f · возраст %.2f · плотность ×%.2f · форма %.2f/%.2f" % [
		float(art_sample.get("patch", 0.5)), float(art_sample.get("fertility", 0.5)), float(art_sample.get("age", 0.5)),
		float(art_sample.get("density_scale", 1.0)), float(art_sample.get("vertical_scale", 1.0)), float(art_sample.get("width_scale", 1.0)),
	]
	_seed_label.text = "Seed: %d · чанков: %d · время: %s\nArt field: %s" % [_seed, _terrain.get_loaded_chunk_count(), _clock.get_display_text() if _clock != null else "—", art_state]
