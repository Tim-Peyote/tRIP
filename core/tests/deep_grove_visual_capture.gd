extends Node

const OUTPUT_PATH: String = "/tmp/trip_deep_grove_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 95, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	level.biome_visual_controller.apply_profile(level.biome_visual_controller.forest_profile, true)
	level.player.global_position = Vector3(20.5, 0.12, 15)
	level.player.rotation.y = -1.5708
	for _frame in 12:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error == OK:
		print("Deep grove capture saved: %s" % OUTPUT_PATH)
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(error)
