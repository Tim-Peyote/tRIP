extends Node

const OUTPUT_PATH: String = "/tmp/trip_menu_camp_capture.png"
const SETTINGS_PATH: String = "/tmp/trip_settings_capture.png"


func _ready() -> void:
	var menu_scene := load("res://features/frontend/main_menu.tscn") as PackedScene
	if menu_scene == null:
		push_error("Could not load the main menu for camp capture.")
		get_tree().quit(1)
		return
	var menu := menu_scene.instantiate() as MainMenu
	add_child(menu)
	menu.camp_backdrop.apply_progress_data({
		"completed_cycles": 4,
		"second_expedition_complete": true,
		"counteragent_brewed": true,
		"root_well_plan": "warded_descent",
	})
	menu.lab_status.text = "ДОРОЖНАЯ ЛАБОРАТОРИЯ · УРОВЕНЬ 4"
	for _frame in 8:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	menu.call("_show_settings")
	await get_tree().process_frame
	var settings_error := get_viewport().get_texture().get_image().save_png(SETTINGS_PATH)
	if error == OK:
		print("Menu captures saved: %s · %s" % [OUTPUT_PATH, SETTINGS_PATH])
	get_tree().quit(error if error != OK else settings_error)
