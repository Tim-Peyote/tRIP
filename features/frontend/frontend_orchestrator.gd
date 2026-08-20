class_name FrontendOrchestrator
extends Node

signal game_requested(slot_id: int, is_new_game: bool)
signal quit_requested

var _menu: MainMenu


func setup(menu: MainMenu) -> void:
	_menu = menu
	_menu.continue_requested.connect(_on_continue_requested)
	_menu.new_game_requested.connect(_on_new_game_requested)
	_menu.quit_requested.connect(func() -> void: quit_requested.emit())
	_menu.set_continue_available(SaveService.has_save(0))


func _on_continue_requested() -> void:
	game_requested.emit(0, false)


func _on_new_game_requested() -> void:
	game_requested.emit(0, true)

