extends Node

const OUTPUT_PATH: String = "/tmp/trip_visual_capture.png"


func _ready() -> void:
	var main_scene := load("res://app/main/main.tscn") as PackedScene
	if main_scene == null:
		push_error("Could not load main scene for visual capture.")
		get_tree().quit(1)
		return
	add_child(main_scene.instantiate())
	for _frame in 5:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error == OK:
		print("Visual capture saved: %s" % OUTPUT_PATH)
	get_tree().quit(error)

