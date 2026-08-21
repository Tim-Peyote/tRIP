class_name TripMain
extends Node

@onready var frontend_orchestrator: FrontendOrchestrator = %FrontendOrchestrator
@onready var main_menu: MainMenu = %MainMenu
@onready var gameplay_hud: GameplayHUD = %GameplayHUD
@onready var presentation_director: PresentationDirector = %PresentationDirector
@onready var audio_director: AudioDirector = %AudioDirector
@onready var world_metamorphosis_director: WorldMetamorphosisDirector = %WorldMetamorphosisDirector
@onready var world_root: Node3D = %WorldRoot
@onready var effect_orchestrator: EffectOrchestrator = %EffectOrchestrator
@onready var world_environment: WorldEnvironment = %WorldEnvironment

const SHELTER_SCENE: PackedScene = preload("res://world/levels/shelter/shelter_level.tscn")

var _active_level: ShelterLevel
var _active_player: FirstPersonController
var _input_diagnostic: Label


func _ready() -> void:
	_setup_input_diagnostic()
	InputBootstrap.ensure_defaults()
	frontend_orchestrator.setup(main_menu)
	frontend_orchestrator.game_requested.connect(_on_game_requested)
	frontend_orchestrator.quit_requested.connect(_on_quit_requested)
	gameplay_hud.resume_requested.connect(_resume_game)
	gameplay_hud.main_menu_requested.connect(_return_to_main_menu)
	gameplay_hud.audio_cue_requested.connect(audio_director.play_ui_cue)
	presentation_director.set_visual_intensity(SettingsService.get_value("accessibility", "visual_intensity", 1.0))
	SettingsService.setting_changed.connect(_on_setting_changed)
	ContentDB.rebuild()
	effect_orchestrator.setup(presentation_director)
	world_metamorphosis_director.transition_started.connect(_on_world_transition_started)
	world_metamorphosis_director.transition_finished.connect(_on_world_transition_finished)


func _process(_delta: float) -> void:
	_update_input_diagnostic()


func _setup_input_diagnostic() -> void:
	_input_diagnostic = Label.new()
	_input_diagnostic.name = "InputDiagnostic"
	_input_diagnostic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_input_diagnostic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_input_diagnostic.add_theme_font_size_override("font_size", 15)
	_input_diagnostic.add_theme_color_override("font_color", Color("d7ff8a"))
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.015, 0.02, 0.015, 0.92)
	background.border_color = Color(0.5, 0.75, 0.28, 0.8)
	background.set_border_width_all(1)
	background.set_corner_radius_all(5)
	background.content_margin_left = 12.0
	background.content_margin_right = 12.0
	background.content_margin_top = 7.0
	background.content_margin_bottom = 7.0
	_input_diagnostic.add_theme_stylebox_override("normal", background)
	_input_diagnostic.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_input_diagnostic.position = Vector2(-390.0, -66.0)
	_input_diagnostic.size = Vector2(780.0, 52.0)
	$UI.add_child(_input_diagnostic)


func _update_input_diagnostic() -> void:
	if _input_diagnostic == null or not is_instance_valid(_input_diagnostic):
		return
	var keys := "W:%d  A:%d  S:%d  D:%d  SPACE:%d" % [
		int(Input.is_physical_key_pressed(KEY_W)),
		int(Input.is_physical_key_pressed(KEY_A)),
		int(Input.is_physical_key_pressed(KEY_S)),
		int(Input.is_physical_key_pressed(KEY_D)),
		int(Input.is_physical_key_pressed(KEY_SPACE)),
	]
	if _active_player == null:
		_input_diagnostic.text = "INPUT QA  |  FOCUS:%d  |  LEVEL:MENU  |  %s  |  MASTER:MUTED" % [
			int(DisplayServer.window_is_focused()), keys,
		]
		return
	_input_diagnostic.text = "INPUT QA  |  FOCUS:%d  PAUSE:%d  GAMEPLAY:%d  CAPTURE:%d  |  %s\nPOS:(%.1f, %.1f, %.1f)  SPEED:%.2f  |  MASTER:MUTED" % [
		int(DisplayServer.window_is_focused()),
		int(get_tree().paused),
		int(_active_player.is_gameplay_enabled()),
		int(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED),
		keys,
		_active_player.global_position.x,
		_active_player.global_position.y,
		_active_player.global_position.z,
		_active_player.get_planar_speed(),
	]


func _unhandled_input(event: InputEvent) -> void:
	if _active_level != null and not get_tree().paused and not event is InputEventKey:
		if event.is_action_pressed(&"inventory"):
			gameplay_hud.call("_toggle_inventory")
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed(&"journal"):
			gameplay_hud.call("_toggle_journal")
			get_viewport().set_input_as_handled()
			return
	if _active_level != null and event.is_action_pressed(&"pause"):
		if _active_level.world_phase_developer_panel.is_panel_visible():
			_active_level.world_phase_developer_panel.set_panel_visible(false)
			get_viewport().set_input_as_handled()
			return
		if not get_tree().paused and gameplay_hud.close_top_overlay():
			get_viewport().set_input_as_handled()
			return
		if get_tree().paused:
			_resume_game()
		else:
			_pause_game()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if _active_level == null or get_tree().paused or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var physical := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	if physical == KEY_I:
		gameplay_hud.call("_toggle_inventory")
		get_viewport().set_input_as_handled()
	elif physical == KEY_J:
		gameplay_hud.call("_toggle_journal")
		get_viewport().set_input_as_handled()


func _on_game_requested(slot_id: int, is_new_game: bool) -> void:
	if _active_level != null:
		return
	get_tree().paused = false
	main_menu.visible = false
	_active_level = SHELTER_SCENE.instantiate() as ShelterLevel
	world_root.add_child(_active_level)
	_active_level.setup_visual_environment(world_environment)
	_active_player = _active_level.get_player()
	world_metamorphosis_director.setup(_active_level.world_phase_orchestrator)
	gameplay_hud.setup(_active_player)
	gameplay_hud.setup_cooking(_active_level.get_cooking_orchestrator())
	gameplay_hud.setup_recipe_knowledge(_active_level.get_recipe_knowledge_orchestrator())
	gameplay_hud.setup_knowledge(_active_level.get_knowledge_orchestrator())
	gameplay_hud.setup_objective(_active_level.get_objective_orchestrator())
	gameplay_hud.setup_clock(_active_level.get_expedition_clock())
	gameplay_hud.setup_stealth(_active_level.get_stealth_orchestrator())
	gameplay_hud.setup_hypotheses(_active_level.get_hypothesis_orchestrator())
	gameplay_hud.setup_game_loop(_active_level.get_game_loop_orchestrator())
	gameplay_hud.setup_spore_tide(_active_level.get_spore_tide())
	gameplay_hud.setup_root_pressure(_active_level.get_root_pressure())
	gameplay_hud.setup_biome_hazard(_active_level.get_biome_hazard())
	gameplay_hud.setup_weather(_active_level.get_weather())
	var persistence := _active_level.get_session_persistence()
	persistence.setup(_active_level, _active_level.get_game_loop_orchestrator(), slot_id)
	gameplay_hud.setup_persistence(persistence)
	if is_new_game:
		SaveService.delete_slot(slot_id)
		persistence.initialize_new()
	elif not persistence.load():
		persistence.initialize_new()
	# Capture explicitly after the menu click and save initialization. Relying on
	# Player._ready() alone lets the embedded game window return focus to the UI.
	_active_player.capture_mouse()
	_active_player.set_gameplay_enabled(true)
	_active_player.inventory.consumable_used.connect(effect_orchestrator.apply_effects)
	_active_player.inventory.consumable_used.connect(_active_player.play_consumption_animation)
	effect_orchestrator.gameplay_channels_changed.connect(_on_effect_gameplay_channels_changed)
	audio_director.set_snapshot(&"default")
	audio_director.play_ui_cue(&"confirm")
	_active_player.interactor.physical_hold_changed.connect(func(active: bool) -> void: audio_director.play_ui_cue(&"grab" if active else &"release"))
	_active_player.interactor.interaction_completed.connect(audio_director.play_ui_cue.bind(&"confirm"))


func _on_quit_requested() -> void:
	get_tree().quit()


func _pause_game() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	gameplay_hud.set_paused(true)
	audio_director.set_snapshot(&"pause")
	audio_director.play_ui_cue(&"pause")


func _resume_game() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	gameplay_hud.set_paused(false)
	audio_director.set_snapshot(&"default")
	audio_director.play_ui_cue(&"close")


func _return_to_main_menu() -> void:
	get_tree().paused = false
	if _active_level != null:
		_active_level.get_session_persistence().save_now(&"return_to_menu")
		_active_level.queue_free()
	effect_orchestrator.clear()
	world_metamorphosis_director.clear()
	_active_level = null
	_active_player = null
	gameplay_hud.clear()
	main_menu.visible = true
	main_menu.refresh_progress()
	main_menu.set_continue_available(SaveService.has_save(0))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	audio_director.set_snapshot(&"default")


func _on_setting_changed(section: StringName, key: StringName, value: Variant) -> void:
	if section == &"accessibility" and key == &"visual_intensity":
		presentation_director.set_visual_intensity(float(value))
	elif section == &"video" and key == &"fov" and _active_player != null:
		_active_player.camera.fov = float(value)


func _on_effect_gameplay_channels_changed(channels: Dictionary[StringName, float]) -> void:
	if _active_level != null:
		_active_level.apply_gameplay_channels(channels)
	if world_metamorphosis_director.is_transitioning():
		return
	if float(channels.get(&"spore_resistance", 0.0)) > 0.1:
		audio_director.set_snapshot(&"spore_quiet")
	elif float(channels.get(&"spore_vision", 0.0)) > 0.1 or float(channels.get(&"crimson_drive", 0.0)) > 0.1:
		audio_director.set_snapshot(&"danger")
	else:
		audio_director.set_snapshot(&"default")


func _on_world_transition_started(definition: WorldPhaseDefinition, _duration: float) -> void:
	audio_director.set_snapshot(&"metamorphosis")
	gameplay_hud.show_notice("МЕТАМОРФОЗА · %s" % definition.display_name.to_upper())


func _on_world_transition_finished(_definition: WorldPhaseDefinition) -> void:
	_on_effect_gameplay_channels_changed(effect_orchestrator.get_gameplay_channels())
