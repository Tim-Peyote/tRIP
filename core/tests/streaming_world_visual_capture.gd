extends Node

const ORDINARY_PATH: String = "/tmp/trip_streaming_world_capture.png"
const ALTERED_PATH: String = "/tmp/trip_world_metamorph_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 117, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	level.biome_visual_controller.apply_profile(level.biome_visual_controller.forest_profile, true)
	var terrain := level.get_node("ExpeditionTerrain") as ExpeditionTerrain
	var viewpoint := Vector3(18, 0, 76)
	viewpoint.y = terrain.get_height_at_global(viewpoint) + 0.12
	terrain.ensure_area_at(viewpoint)
	level.player.global_position = viewpoint
	level.player.rotation.y = 3.14159
	for _frame in 28:
		await get_tree().process_frame
	var ordinary := get_viewport().get_texture().get_image()
	var first_error := ordinary.save_png(ORDINARY_PATH)
	terrain.set_world_phase(ExpeditionTerrain.PHASE_MYCELIAL)
	terrain.call("_set_phase_amount", 1.0)
	level.biome_visual_controller.set_metamorphosis(true)
	level.biome_visual_controller.apply_profile(level.biome_visual_controller.mycelial_profile, true)
	for _frame in 6:
		await get_tree().process_frame
	var altered := get_viewport().get_texture().get_image()
	var second_error := altered.save_png(ALTERED_PATH)
	if first_error == OK and second_error == OK:
		print("Streaming world captures saved.")
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(first_error if first_error != OK else second_error)
