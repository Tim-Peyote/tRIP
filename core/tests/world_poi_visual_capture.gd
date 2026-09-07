extends Node

const OUTPUT_PATH := "/tmp/trip_world_poi_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 88, true)
	await get_tree().process_frame
	var level := main.find_child("ExpeditionSession", true, false) as SessionController
	level.world_phase_orchestrator.set_developer_phase(&"phase.crimson_hunt")
	await get_tree().create_timer(2.2).timeout
	var terrain := level.get_node("ExpeditionTerrain") as ExpeditionTerrain
	for _frame: int in 30:
		await get_tree().process_frame
	var pois := terrain.find_children("*", "WorldMysteryPOI", true, false)
	if pois.is_empty():
		push_error("No generated world POI available for capture.")
		get_tree().quit(1)
		return
	var poi := pois[0] as WorldMysteryPOI
	var target := (poi.get_node("MysteryCollision") as CollisionShape3D).global_position - Vector3.UP * 1.9
	var player_position := target + Vector3(0, 0, 4.8)
	player_position.y = terrain.get_height_at_global(player_position) + 0.18
	level.player.global_position = player_position
	level.player.rotation.y = 0.0
	(level.player.get_node("CameraRig") as Node3D).rotation.x = -0.32
	var interactable := poi.find_child("InteractableComponent", true, false) as InteractableComponent
	interactable.complete_interaction(level.player)
	level.player.velocity = Vector3(1.5, 0.0, 0.0)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	for _frame: int in 28:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error == OK:
		print("World POI capture saved: %s" % OUTPUT_PATH)
	main.free()
	get_tree().quit(error)
