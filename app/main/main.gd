class_name TripMain
extends Node

@onready var frontend_orchestrator: FrontendOrchestrator = %FrontendOrchestrator
@onready var main_menu: MainMenu = %MainMenu
@onready var gameplay_hud: GameplayHUD = %GameplayHUD
@onready var presentation_director: PresentationDirector = %PresentationDirector
@onready var audio_director: AudioDirector = %AudioDirector
@onready var world_root: Node3D = %WorldRoot
@onready var effect_orchestrator: EffectOrchestrator = %EffectOrchestrator
@onready var world_environment: WorldEnvironment = %WorldEnvironment

const SHELTER_SCENE: PackedScene = preload("res://world/levels/shelter/shelter_level.tscn")

var _active_level: ShelterLevel
var _active_player: FirstPersonController


func _ready() -> void:
	InputBootstrap.ensure_defaults()
	frontend_orchestrator.setup(main_menu)
	frontend_orchestrator.game_requested.connect(_on_game_requested)
	frontend_orchestrator.quit_requested.connect(_on_quit_requested)
	gameplay_hud.resume_requested.connect(_resume_game)
	gameplay_hud.main_menu_requested.connect(_return_to_main_menu)
	presentation_director.set_visual_intensity(SettingsService.get_value("accessibility", "visual_intensity", 1.0))
	SettingsService.setting_changed.connect(_on_setting_changed)
	ContentDB.rebuild()
	effect_orchestrator.setup(presentation_director)


func _unhandled_input(event: InputEvent) -> void:
	if _active_level != null and event.is_action_pressed(&"pause"):
		if get_tree().paused:
			_resume_game()
		else:
			_pause_game()
		get_viewport().set_input_as_handled()


func _on_game_requested(slot_id: int, is_new_game: bool) -> void:
	if _active_level != null:
		return
	main_menu.visible = false
	_active_level = SHELTER_SCENE.instantiate() as ShelterLevel
	world_root.add_child(_active_level)
	_active_level.setup_visual_environment(world_environment)
	_active_player = _active_level.get_player()
	gameplay_hud.setup(_active_player)
	gameplay_hud.setup_cooking(_active_level.get_cooking_orchestrator())
	gameplay_hud.setup_knowledge(_active_level.get_knowledge_orchestrator())
	gameplay_hud.setup_objective(_active_level.get_objective_orchestrator())
	gameplay_hud.setup_clock(_active_level.get_expedition_clock())
	gameplay_hud.setup_stealth(_active_level.get_stealth_orchestrator())
	gameplay_hud.setup_hypotheses(_active_level.get_hypothesis_orchestrator())
	gameplay_hud.setup_game_loop(_active_level.get_game_loop_orchestrator())
	var persistence := _active_level.get_session_persistence()
	persistence.setup(_active_level, _active_level.get_game_loop_orchestrator(), slot_id)
	gameplay_hud.setup_persistence(persistence)
	if is_new_game:
		SaveService.delete_slot(slot_id)
		persistence.initialize_new()
	elif not persistence.load():
		persistence.initialize_new()
	_active_player.inventory.consumable_used.connect(effect_orchestrator.apply_effects)
	_active_player.inventory.consumable_used.connect(_active_player.play_consumption_animation)
	effect_orchestrator.gameplay_channels_changed.connect(_active_level.apply_gameplay_channels)
	audio_director.set_snapshot(&"default")


func _on_quit_requested() -> void:
	get_tree().quit()


func _pause_game() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	gameplay_hud.set_paused(true)
	audio_director.set_snapshot(&"pause")


func _resume_game() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	gameplay_hud.set_paused(false)
	audio_director.set_snapshot(&"default")


func _return_to_main_menu() -> void:
	get_tree().paused = false
	if _active_level != null:
		_active_level.get_session_persistence().save_now(&"return_to_menu")
		_active_level.queue_free()
	effect_orchestrator.clear()
	_active_level = null
	_active_player = null
	gameplay_hud.clear()
	main_menu.visible = true
	main_menu.set_continue_available(SaveService.has_save(0))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	audio_director.set_snapshot(&"default")


func _on_setting_changed(section: StringName, key: StringName, value: Variant) -> void:
	if section == &"accessibility" and key == &"visual_intensity":
		presentation_director.set_visual_intensity(float(value))
