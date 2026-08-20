extends Node

const OUTPUT_PATH: String = "/tmp/trip_gameplay_capture.png"


func _ready() -> void:
	var packed := load("res://app/main/main.tscn") as PackedScene
	var main := packed.instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 91, true)
	await get_tree().physics_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error == OK:
		print("Gameplay capture saved: %s" % OUTPUT_PATH)
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(error)
