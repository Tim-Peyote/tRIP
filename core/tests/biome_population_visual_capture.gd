extends Node

const OUTPUT_PATH := "/tmp/trip_biome_population_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 517, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	main.world_metamorphosis_director.finish_immediately()
	main.gameplay_hud.notice_label.visible = false
	var terrain := level.get_node("ExpeditionTerrain") as ExpeditionTerrain
	var destination := Vector3(terrain.call("_route_center_x", 76.0), 0.0, 76.0)
	destination.y = terrain.get_height_at_global(destination) + 0.18
	terrain.ensure_area_at(destination)
	level.player.global_position = destination
	for _frame: int in 36: await get_tree().process_frame
	var population := level.get_biome_population()
	population.developer_cycle_density()
	population.developer_respawn()
	for _frame: int in 12: await get_tree().process_frame
	var actors := population.find_children("Creature_*", "BiomeCreatureActor", true, false)
	if actors.is_empty():
		push_error("No fauna generated for visual capture.")
		get_tree().quit(1)
		return
	var actor := actors[0] as BiomeCreatureActor
	var target := actor.global_position + Vector3(0, 0.8 * actor.definition.visual_scale, 0)
	var offset := Vector3(7.5, 1.6, 9.0)
	level.player.global_position = target + offset
	level.player.look_at(target, Vector3.UP)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	for _frame: int in 10: await get_tree().process_frame
	var error := get_viewport().get_texture().get_image().save_png(OUTPUT_PATH)
	if error == OK:
		print("Biome population capture saved: %s · %s" % [OUTPUT_PATH, actor.definition.display_name])
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(error)
