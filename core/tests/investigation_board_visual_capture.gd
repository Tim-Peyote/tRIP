extends Node

const OUTPUT_PATH: String = "/tmp/trip_investigation_board_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 96, true)
	await get_tree().process_frame
	var level := main.find_child("ExpeditionSession", true, false) as SessionController
	var loop := level.game_loop_orchestrator
	loop.stage = GameLoopOrchestrator.Stage.DEEP_GROVE
	loop.route_unlocked = true
	loop.counteragent_brewed = true
	loop.record_trail_clue(&"mycologist.trail.notch", "Зарубка", "Путь ведёт на север.")
	loop.record_trail_clue(&"mycologist.camp.abandoned", "Лагерь", "Ягода защищает от голоса.")
	loop.record_trail_clue(&"mycologist.ring.surge_trace", "Координаты", "Корневой колодец находится под древним кольцом.")
	loop.select_root_well_plan(&"resonant_descent")
	level.player.global_position = Vector3(1.7, 0.12, -1.4)
	level.player.rotation.y = -1.5708
	for _frame in 50:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error == OK:
		print("Investigation board capture saved: %s" % OUTPUT_PATH)
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(error)
