class_name MainMenu
extends Control

signal continue_requested
signal new_game_requested
signal quit_requested

@onready var continue_button: Button = %ContinueButton
@onready var settings_panel: SettingsPanel = %SettingsPanel
@onready var notice_label: Label = %NoticeLabel
@onready var camp_backdrop: MenuCampBackdrop = %MenuCampBackdrop
@onready var lab_status: Label = %LabStatus


func _ready() -> void:
	for button: Button in [%ContinueButton, %NewGameButton, %SettingsButton, %CreditsButton, %QuitButton]:
		for state: StringName in [&"normal", &"hover", &"focus", &"pressed", &"disabled"]:
			button.add_theme_stylebox_override(state, TripUITheme.make_inventory_tab(state))
		button.add_theme_color_override("font_color", TripUITheme.BONE)
		button.add_theme_color_override("font_pressed_color", TripUITheme.BONE)
		button.add_theme_color_override("font_focus_color", TripUITheme.PAPER)
	if theme == null:
		theme = preload("res://presentation/ui/trip_theme.tres")
	%ContinueButton.pressed.connect(func() -> void: continue_requested.emit())
	%NewGameButton.pressed.connect(func() -> void: new_game_requested.emit())
	%SettingsButton.pressed.connect(_show_settings)
	%CreditsButton.pressed.connect(_show_credits)
	%QuitButton.pressed.connect(func() -> void: quit_requested.emit())
	settings_panel.closed.connect(_hide_settings)
	%NewGameButton.grab_focus()
	refresh_progress()
	_animate_entrance()


func _animate_entrance() -> void:
	var layout := $SafeArea/Layout as Control
	layout.modulate.a = 0.0
	layout.position.x -= 24.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(layout, "modulate:a", 1.0, 0.7)
	tween.tween_property(layout, "position:x", layout.position.x + 24.0, 0.7)


func refresh_progress() -> void:
	if camp_backdrop == null:
		return
	camp_backdrop.refresh_from_save()
	lab_status.text = "ДОРОЖНАЯ ЛАБОРАТОРИЯ · УРОВЕНЬ %d" % camp_backdrop.get_laboratory_level()


func set_continue_available(is_available: bool) -> void:
	continue_button.visible = is_available
	continue_button.disabled = not is_available


func show_notice(message: String) -> void:
	notice_label.text = message
	notice_label.visible = true


func _show_settings() -> void:
	_set_menu_buttons_enabled(false)
	settings_panel.visible = true
	settings_panel.focus_first_control()


func _hide_settings() -> void:
	settings_panel.visible = false
	_set_menu_buttons_enabled(true)
	%SettingsButton.grab_focus()


func _show_credits() -> void:
	show_notice("TRip — создаётся вместе с лесом. Версия pre-production.")


func _set_menu_buttons_enabled(value: bool) -> void:
	for button_name: String in ["ContinueButton", "NewGameButton", "SettingsButton", "CreditsButton", "QuitButton"]:
		var button := get_node("SafeArea/Layout/%s" % button_name) as Button
		button.disabled = not value
