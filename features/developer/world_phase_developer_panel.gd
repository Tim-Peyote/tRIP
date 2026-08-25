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
var _panel: PanelContainer
var _status: Label
var _seed_label: Label
var _seed: int = 117
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _status_elapsed: float = 0.0


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
	if key.keycode == KEY_F10:
		set_panel_visible(not _panel.visible)
		get_viewport().set_input_as_handled()
		return
	if not _panel.visible:
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_8:
		_set_phase_by_index(int(key.keycode - KEY_1))
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_PAGEUP:
		_cycle_phase(-1)
	elif key.keycode == KEY_PAGEDOWN:
		_cycle_phase(1)
	elif key.keycode == KEY_R:
		_randomize_seed()
	elif key.keycode == KEY_BACKSPACE:
		_orchestrator.clear_developer_override()
	elif key.keycode == KEY_ENTER and _progression != null:
		_progression.simulate_transition_formula()
	elif key.keycode == KEY_P and _progression != null:
		_progression.simulate_nearest_mystery_event()
	elif key.keycode == KEY_H and _hazard != null:
		_hazard.force_active()
	elif key.keycode == KEY_DELETE and _hazard != null:
		_hazard.developer_clear()
	elif key.keycode == KEY_M and _laboratory != null:
		_laboratory.developer_toggle(not key.shift_pressed)
	elif key.keycode == KEY_T:
		_teleport_route_ahead()
	elif key.keycode == KEY_O:
		_teleport_to_nearest(&"poi")
	elif key.keycode == KEY_C:
		_teleport_to_nearest(&"composition")
	elif key.keycode == KEY_I:
		_add_current_biome_sample()
	elif key.keycode == KEY_Y:
		_cycle_time()
	elif key.keycode == KEY_K and _population != null:
		_population.developer_respawn()
	elif key.keycode == KEY_N and _population != null:
		_population.developer_cycle_density()
	elif key.keycode == KEY_W and _weather != null:
		_weather.developer_cycle()
	elif key.keycode == KEY_B:
		_teleport_to_physics_lab()
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
	_panel.position = Vector2(18, 44)
	_panel.custom_minimum_size = Vector2(610, 530)
	_panel.theme = TripUITheme.build()
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
	title.text = "TRip · ПУЛЬТ РАЗРАБОТЧИКА"
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_seed_label = Label.new()
	column.add_child(_seed_label)
	var scroll := ScrollContainer.new()
	# Status gained local weather and physiology lines; keep the tool list itself
	# scrollable instead of allowing the entire QA panel to leave a 720p viewport.
	scroll.custom_minimum_size = Vector2(0, 215)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var tools := VBoxContainer.new()
	tools.name = "DeveloperTools"
	tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_theme_constant_override("separation", 9)
	scroll.add_child(tools)
	var world_header := Label.new()
	world_header.text = "МИРЫ · клавиши 1–8"
	world_header.modulate = Color(0.72, 0.82, 0.56)
	tools.add_child(world_header)
	var world_grid := GridContainer.new()
	world_grid.columns = 2
	world_grid.add_theme_constant_override("h_separation", 7)
	world_grid.add_theme_constant_override("v_separation", 5)
	tools.add_child(world_grid)
	var definitions := _orchestrator.get_definitions()
	for definition: WorldPhaseDefinition in definitions:
		var button := Button.new()
		button.text = "%d · %s" % [definition.order + 1, definition.display_name]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.x = 270
		button.pressed.connect(_orchestrator.set_developer_phase.bind(definition.id))
		world_grid.add_child(button)
	var action_header := Label.new()
	action_header.text = "СЦЕНАРИИ QA"
	action_header.modulate = Color(0.72, 0.82, 0.56)
	tools.add_child(action_header)
	var action_grid := GridContainer.new()
	action_grid.columns = 2
	action_grid.add_theme_constant_override("h_separation", 7)
	action_grid.add_theme_constant_override("v_separation", 5)
	tools.add_child(action_grid)
	if _progression != null:
		_add_action_button(action_grid, "Enter · принять формулу", _progression.simulate_transition_formula)
		_add_action_button(action_grid, "P · решить событие POI", _progression.simulate_nearest_mystery_event)
	if _hazard != null:
		_add_action_button(action_grid, "H · запустить явление", _hazard.force_active)
		_add_action_button(action_grid, "Delete · очистить явление", _hazard.developer_clear)
	if _laboratory != null:
		_add_action_button(action_grid, "M · лаборатория с эффектом", _toggle_laboratory.bind(true))
		_add_action_button(action_grid, "Shift+M · мгновенно", _toggle_laboratory.bind(false))
	_add_action_button(action_grid, "T · маршрут +90 м", _teleport_route_ahead)
	_add_action_button(action_grid, "O · к ближайшему POI", _teleport_to_nearest.bind(&"poi"))
	_add_action_button(action_grid, "C · к экокомпозиции", _teleport_to_nearest.bind(&"composition"))
	_add_action_button(action_grid, "I · образец текущего мира", _add_current_biome_sample)
	if _clock != null:
		_add_action_button(action_grid, "Y · сменить время", _cycle_time)
	if _persistence != null:
		_add_action_button(action_grid, "Сохранить сейчас", _persistence.save_now.bind(&"developer_manual"))
	if _population != null:
		_add_action_button(action_grid, "K · переселить живность", _population.developer_respawn)
		_add_action_button(action_grid, "N · плотность фауны", _population.developer_cycle_density)
	_add_action_button(action_grid, "R · новый seed", _randomize_seed)
	_add_action_button(action_grid, "B · физический стенд", _teleport_to_physics_lab)
	if _weather != null:
		_add_action_button(action_grid, "W · следующая погода", _weather.developer_cycle)
	if _player != null and _player.vitals != null:
		_add_action_button(action_grid, "Тело · восстановить", _player.vitals.developer_restore)
		_add_action_button(action_grid, "Тело · холод", _player.vitals.developer_set_condition.bind(&"cold"))
		_add_action_button(action_grid, "Тело · замерзание", _player.vitals.developer_set_condition.bind(&"freezing"))
		_add_action_button(action_grid, "Тело · отравление", _player.vitals.developer_set_condition.bind(&"toxic"))
		_add_action_button(action_grid, "Тело · споры", _player.vitals.developer_set_condition.bind(&"spores"))
		_add_action_button(action_grid, "Тело · истощение", _player.vitals.developer_set_condition.bind(&"exhausted"))
	_add_action_button(action_grid, "Backspace · реальный мир", _orchestrator.clear_developer_override)
	var help := Label.new()
	help.text = "PgUp/PgDn — соседний мир · 1–8 — прямой выбор · F10 — закрыть"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.modulate = Color(0.68, 0.76, 0.62)
	column.add_child(help)


func _rebuild_weather_controls() -> void:
	if _panel == null or _weather == null:
		return
	var column := _panel.find_child("WeatherDeveloperControls", true, false) as HBoxContainer
	if column != null:
		return
	column = HBoxContainer.new()
	column.name = "WeatherDeveloperControls"
	column.add_theme_constant_override("separation", 6)
	# Keep quick weather controls inside the existing scroll region at 720p.
	var tools := _panel.find_child("DeveloperTools", true, false) as VBoxContainer
	if tools == null:
		return
	tools.add_child(column)
	for weather_state: int in WeatherOrchestrator.State.values():
		var button := Button.new()
		button.text = ["Ясно", "Дождь", "Гроза", "Туман", "Снег"][weather_state]
		button.pressed.connect(_weather.developer_set.bind(weather_state))
		column.add_child(button)


func _add_action_button(parent: Control, text_value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.x = 270
	button.pressed.connect(callback)
	parent.add_child(button)


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
	_seed_label.text = "Seed: %d · чанков: %d · время: %s" % [_seed, _terrain.get_loaded_chunk_count(), _clock.get_display_text() if _clock != null else "—"]
