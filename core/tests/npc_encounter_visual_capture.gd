extends Node

const OUTPUT_PATH := "/tmp/trip_ilya_root_echo_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 731, true)
	await get_tree().process_frame
	var level := main.find_child("ExpeditionSession", true, false) as SessionController
	var terrain := level.get_node("ExpeditionTerrain") as ExpeditionTerrain
	level.world_phase_orchestrator.set_developer_phase(&"phase.root_dream")
	terrain.call("_set_phase_amount", 1.0)
	level.biome_visual_controller.apply_profile(level.world_phase_orchestrator.get_current().visual_profile, true)
	var probe := StaticBody3D.new()
	terrain.add_child(probe)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9441
	terrain.call("_add_point_of_interest", probe, Vector2i(0, 4), rng)
	await get_tree().process_frame
	var encounter := probe.find_child("IlyaRootEcho", true, false) as AuthoredNPCEncounter
	if encounter == null:
		push_error("Root Dream encounter was not generated for capture.")
		get_tree().quit(1)
		return
	var target := encounter.global_position + Vector3.UP * 1.05
	level.player.global_position = target + Vector3(0.0, 0.12, -3.55)
	level.player.look_at(target, Vector3.UP)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	main.gameplay_hud.notice_label.visible = false
	for _frame: int in 18:
		await get_tree().process_frame
	var error := get_viewport().get_texture().get_image().save_png(OUTPUT_PATH)
	if error == OK:
		print("Ilya encounter capture saved: %s" % OUTPUT_PATH)
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(error)
