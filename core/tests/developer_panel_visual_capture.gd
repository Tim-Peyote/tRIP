extends Node

const OUTPUT_PATH := "/tmp/trip_developer_panel_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 419, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	level.world_phase_developer_panel.set_panel_visible(true)
	for _frame: int in 3:
		await get_tree().process_frame
	var error := get_viewport().get_texture().get_image().save_png(OUTPUT_PATH)
	if error == OK:
		print("Developer panel capture saved: %s" % OUTPUT_PATH)
	get_tree().quit(error)
