extends Node

const OUTPUT_PATH: String = "/tmp/trip_forest_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 0, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	level.player.global_position = Vector3(0, 0.12, 9.5)
	level.player.rotation.y = 3.14159
	for _frame in 8:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error == OK:
		print("Forest capture saved: %s" % OUTPUT_PATH)
	main.free()
	get_tree().quit(error)
