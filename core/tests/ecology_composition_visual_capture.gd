extends Node

const OUTPUT_PATH := "/tmp/trip_ecology_composition_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 204, true)
	await get_tree().process_frame
	var level := main.find_child("ExpeditionSession", true, false) as SessionController
	level.world_phase_orchestrator.set_developer_phase(&"phase.glass_frost")
	main.world_metamorphosis_director.finish_immediately()
	main.gameplay_hud.notice_label.visible = false
	var terrain := level.get_node("ExpeditionTerrain") as ExpeditionTerrain
	var pack := level.world_phase_orchestrator.get_current().content_pack
	var center := terrain.call("_composition_center_for_row", 3, pack) as Vector2
	var view_z := center.y - 13.0
	var center_height := terrain.get_height_at_global(Vector3(center.x, 0.0, center.y))
	var viewpoint := Vector3(center.x, center_height + 4.4, view_z)
	terrain.ensure_area_at(Vector3(center.x, 0.0, center.y))
	level.player.global_position = viewpoint
	level.player.look_at(Vector3(center.x, center_height + 2.1, center.y), Vector3.UP)
	(level.player.get_node("CameraRig") as Node3D).rotation.x = -0.05
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	level.get_biome_hazard().set_process(false)
	for _frame: int in 42:
		await get_tree().process_frame
	var compositions := terrain.find_children("EcologyComposition_*", "Node3D", true, false)
	if compositions.is_empty():
		push_error("No ecology composition generated for capture.")
		get_tree().quit(1)
		return
	var error := get_viewport().get_texture().get_image().save_png(OUTPUT_PATH)
	if error == OK:
		print("Ecology composition capture saved: %s" % OUTPUT_PATH)
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(error)
