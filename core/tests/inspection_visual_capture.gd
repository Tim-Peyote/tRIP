extends Node

const OUTPUT_PATH: String = "/tmp/trip_inspection_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 94, true)
	await get_tree().process_frame
	var hud := main.gameplay_hud
	hud.call("_on_inspection_definition_requested", &"ingredient.mooncap", "", "")
	hud.inspection_view.set_zoom(0.72)
	hud.inspection_view.rotate_sample(24.0, -5.0)
	for _frame in 10:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error == OK:
		print("Inspection capture saved: %s" % OUTPUT_PATH)
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(error)
