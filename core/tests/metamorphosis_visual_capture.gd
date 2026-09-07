extends Node

const OUTPUT_PATH: String = "/tmp/trip_metamorphosis_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 149, true)
	await get_tree().process_frame
	var level := main.find_child("ExpeditionSession", true, false) as SessionController
	level.biome_visual_controller.apply_profile(level.biome_visual_controller.forest_profile, true)
	var terrain := level.get_node("ExpeditionTerrain") as ExpeditionTerrain
	var route_z := 118.0
	var viewpoint := Vector3(float(terrain.call("_route_center_x", route_z)), 0.0, route_z)
	viewpoint.y = terrain.get_height_at_global(viewpoint) + 0.12
	terrain.ensure_area_at(viewpoint)
	level.player.global_position = viewpoint
	level.player.rotation.y = PI
	for _frame in 20:
		await get_tree().process_frame
	main.effect_orchestrator.apply_effects([&"effect.spore_sight"], "Настой спорозрения")
	await get_tree().create_timer(1.28).timeout
	var error := get_viewport().get_texture().get_image().save_png(OUTPUT_PATH)
	if error == OK:
		print("Metamorphosis capture saved: %s" % OUTPUT_PATH)
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(error)
