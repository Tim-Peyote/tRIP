extends Node

const OUTPUT_PATH := "/tmp/trip_world_poi_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 88, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	level.world_phase_orchestrator.set_developer_phase(&"phase.crimson_hunt")
	await get_tree().create_timer(2.2).timeout
	var terrain := level.get_node("ExpeditionTerrain") as ExpeditionTerrain
	for _frame: int in 30:
		await get_tree().process_frame
	var samples := terrain.find_children("*", "GeneratedBiomeIngredient", true, false)
	if samples.is_empty():
		push_error("No generated world POI sample available for capture.")
		get_tree().quit(1)
		return
	var target := (samples[0] as GeneratedBiomeIngredient).global_position
	var player_position := target + Vector3(0, 0, 5.8)
	player_position.y = terrain.get_height_at_global(player_position) + 0.18
	level.player.global_position = player_position
	level.player.rotation.y = 0.0
	(level.player.get_node("CameraRig") as Node3D).rotation.x = -0.32
	for _frame: int in 18:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error == OK:
		print("World POI capture saved: %s" % OUTPUT_PATH)
	main.free()
	get_tree().quit(error)
