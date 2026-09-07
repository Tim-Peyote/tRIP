extends Node

const OUTPUT_PATH := "/tmp/trip_third_person_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 731, true)
	await get_tree().process_frame
	var level := main.find_child("ExpeditionSession", true, false) as SessionController
	level.player.set_third_person_enabled(true, false)
	level.player.set_gameplay_input_override_for_testing(true)
	level.player.rotation.y = 0.18
	Input.action_press(&"move_forward")
	for _frame: int in 40:
		await get_tree().physics_frame
	for _frame: int in 3:
		await get_tree().process_frame
	var error := get_viewport().get_texture().get_image().save_png(OUTPUT_PATH)
	if error == OK:
		print("Third-person capture saved: %s" % OUTPUT_PATH)
	Input.action_release(&"move_forward")
	get_tree().quit(error)
