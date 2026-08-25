extends Node

const OUTPUT_PATH := "/tmp/trip_pause_settings_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 812, true)
	await get_tree().process_frame
	main.call("_pause_game")
	main.gameplay_hud.call("_show_pause_settings")
	for _frame: int in 4:
		await get_tree().process_frame
	var error := get_viewport().get_texture().get_image().save_png(OUTPUT_PATH)
	if error == OK:
		print("Pause settings capture saved: %s" % OUTPUT_PATH)
	get_tree().paused = false
	get_tree().quit(error)
