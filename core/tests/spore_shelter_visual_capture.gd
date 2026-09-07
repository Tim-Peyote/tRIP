extends Node

const OUTPUT_PATH: String = "/tmp/trip_spore_shelter_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 97, true)
	await get_tree().process_frame
	var level := main.find_child("ExpeditionSession", true, false) as SessionController
	level.biome_visual_controller.apply_profile(level.biome_visual_controller.forest_profile, true)
	level.player.global_position = Vector3(18.2, 0.12, 9.8)
	level.player.rotation.y = -2.29
	level.spore_tide.force_state(SporeTideOrchestrator.State.SURGE)
	level.spore_tide.exposure = 0.58
	for _frame in 20:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error == OK:
		print("Spore shelter capture saved: %s" % OUTPUT_PATH)
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(error)
