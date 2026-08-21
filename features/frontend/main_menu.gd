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
	%ContinueButton.pressed.connect(func() -> void: continue_requested.emit())
	%NewGameButton.pressed.connect(func() -> void: new_game_requested.emit())
	%SettingsButton.pressed.connect(_show_settings)
	%CreditsButton.pressed.connect(_show_credits)
	%QuitButton.pressed.connect(func() -> void: quit_requested.emit())
	settings_panel.closed.connect(_hide_settings)
	%NewGameButton.grab_focus()
	refresh_progress()


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
	settings_panel.visible = true
	settings_panel.focus_first_control()


func _hide_settings() -> void:
	settings_panel.visible = false
	%SettingsButton.grab_focus()


func _show_credits() -> void:
	show_notice("TRip — создаётся вместе с лесом. Версия pre-production.")
