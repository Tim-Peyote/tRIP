extends Node

const OUTPUT_PATH: String = "/tmp/trip_root_well_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	main.session_scene = load("res://core/tests/fixtures/legacy_expedition_fixture.tscn") as PackedScene
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 95, true)
	await get_tree().process_frame
	var level := main.find_child("LegacyExpeditionFixture", true, false) as LegacyExpeditionFixture
	var loop := level.game_loop_orchestrator
	loop.stage = GameLoopOrchestrator.Stage.DEEP_GROVE
	loop.route_unlocked = true
	loop.counteragent_brewed = true
	loop.record_trail_clue(&"mycologist.ring.surge_trace", "Координаты", "Корневой колодец найден.")
	loop.select_root_well_plan(&"resonant_descent")
	loop.record_root_well_entered(level.player)
	level.biome_visual_controller.apply_profile(level.biome_visual_controller.forest_profile, true)
	level.player.global_position = level.root_well.to_global(Vector3(0, 0.2, 11.2))
	level.player.rotation.y = 0.0
	level.player.camera_rig.rotation.x = -0.16
	level.root_well.pressure.force_state(RootPressureOrchestrator.State.HUNTING)
	level.root_well.pressure.pressure = 0.46
	for _frame in 55:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error == OK:
		print("Root well capture saved: %s" % OUTPUT_PATH)
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(error)
