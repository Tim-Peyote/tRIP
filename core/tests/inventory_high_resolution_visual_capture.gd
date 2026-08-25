extends Node

const OUTPUT_PATH := "/tmp/trip_inventory_high_resolution_capture.png"


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(2880, 1800))
	for _frame: int in 3:
		await get_tree().process_frame
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 903, true)
	await get_tree().process_frame
	main.gameplay_hud.call("_toggle_inventory")
	for _frame: int in 6:
		await get_tree().process_frame
	var error := get_viewport().get_texture().get_image().save_png(OUTPUT_PATH)
	if error == OK:
		print("High-resolution inventory capture saved: %s" % OUTPUT_PATH)
	get_tree().quit(error)
