extends Node

const OUTPUT_PATH: String = "/tmp/trip_shelter_progress_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 96, true)
	await get_tree().process_frame
	var level := main.find_child("ExpeditionSession", true, false) as SessionController
	level.game_loop_orchestrator.apply_save_data({
		"stage": GameLoopOrchestrator.Stage.DEEP_GROVE,
		"route_unlocked": true,
		"completed_cycles": 2,
		"second_expedition_complete": true,
	})
	level.player.global_position = Vector3(0.2, 0.12, 2.65)
	level.player.rotation.y = 0.0
	for _frame in 12:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error == OK:
		print("Shelter progression capture saved: %s" % OUTPUT_PATH)
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(error)
