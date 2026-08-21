extends Node

const OUTPUT_PATH := "/tmp/trip_biome_hazard_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 151, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	level.world_phase_orchestrator.set_developer_phase(&"phase.glass_frost")
	main.world_metamorphosis_director.finish_immediately()
	main.gameplay_hud.notice_label.visible = false
	var terrain := level.get_node("ExpeditionTerrain") as ExpeditionTerrain
	var route_z := 132.0
	var viewpoint := Vector3(float(terrain.call("_route_center_x", route_z)), 0.0, route_z)
	viewpoint.y = terrain.get_height_at_global(viewpoint) + 0.18
	terrain.ensure_area_at(viewpoint)
	level.player.global_position = viewpoint
	level.player.rotation.y = PI
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	level.get_biome_hazard().force_active()
	level.get_biome_hazard().exposure = 0.62
	for _frame: int in 42:
		await get_tree().process_frame
	var error := get_viewport().get_texture().get_image().save_png(OUTPUT_PATH)
	if error == OK:
		print("Biome hazard capture saved: %s" % OUTPUT_PATH)
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(error)
