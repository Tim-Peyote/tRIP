extends Node

const OUTPUT_PATH := "/tmp/trip_inventory_empty_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 902, true)
	await get_tree().process_frame
	main.gameplay_hud.call("_toggle_inventory")
	for _frame: int in 5:
		await get_tree().process_frame
	var error := get_viewport().get_texture().get_image().save_png(OUTPUT_PATH)
	if error == OK:
		print("Empty inventory capture saved: %s" % OUTPUT_PATH)
	get_tree().quit(error)
