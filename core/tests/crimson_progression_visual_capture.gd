extends Node

const INGREDIENT_PATH: String = "/tmp/trip_blood_antler_capture.png"
const WORLD_PATH: String = "/tmp/trip_crimson_hunt_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 151, true)
	await get_tree().process_frame
	var level := main.find_child("ExpeditionSession", true, false) as SessionController
	var terrain := level.get_node("ExpeditionTerrain") as ExpeditionTerrain
	var viewpoint := Vector3(-3.35, 0.0, 38.8)
	viewpoint.y = terrain.get_height_at_global(viewpoint) + 0.12
	terrain.ensure_area_at(viewpoint)
	level.player.global_position = viewpoint
	level.player.rotation.y = PI
	main.effect_orchestrator.apply_effects([&"effect.spore_sight"])
	terrain.call("_set_phase_amount", 1.0)
	level.biome_visual_controller.apply_profile(level.world_phase_orchestrator.get_current().visual_profile, true)
	main.world_metamorphosis_director.finish_immediately()
	for _frame in 10:
		await get_tree().process_frame
	var ingredient_error := get_viewport().get_texture().get_image().save_png(INGREDIENT_PATH)
	main.effect_orchestrator.apply_effects([&"effect.crimson_drive"])
	terrain.call("_set_phase_amount", 1.0)
	level.biome_visual_controller.apply_profile(level.world_phase_orchestrator.get_current().visual_profile, true)
	main.world_metamorphosis_director.finish_immediately()
	for _frame in 8:
		await get_tree().process_frame
	var world_error := get_viewport().get_texture().get_image().save_png(WORLD_PATH)
	if ingredient_error == OK and world_error == OK:
		print("Crimson progression captures saved.")
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(ingredient_error if ingredient_error != OK else world_error)
