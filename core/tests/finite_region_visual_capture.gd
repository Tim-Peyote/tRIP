extends Node

const TAIGA_RIM_PATH := "/tmp/trip_finite_taiga_rim_capture.png"
const FROST_RIM_PATH := "/tmp/trip_finite_frost_rim_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 1701, true)
	await get_tree().process_frame
	var level := main.find_child("ExpeditionSession", true, false) as SessionController
	var terrain := level.get_node("ExpeditionTerrain") as ExpeditionTerrain
	level.get_weather().automatic = false
	level.get_weather().set_weather(WeatherOrchestrator.State.CLEAR, 0.18, true)
	main.gameplay_hud.notice_timer.stop()
	main.gameplay_hud.notice_label.visible = false
	var error := await _capture_rim(level, terrain, TAIGA_RIM_PATH)
	if error == OK:
		level.world_phase_orchestrator.set_developer_phase(&"phase.glass_frost")
		terrain.call("_set_phase_amount", 1.0)
		level.biome_visual_controller.apply_profile(level.world_phase_orchestrator.get_current().visual_profile, true)
		level.get_weather().set_weather(WeatherOrchestrator.State.SNOW, 0.58, true)
		error = await _capture_rim(level, terrain, FROST_RIM_PATH)
	if error == OK:
		print("Finite region rim captures saved.")
	get_tree().quit(error)


func _capture_rim(level: SessionController, terrain: ExpeditionTerrain, path: String) -> Error:
	var pack := level.world_phase_orchestrator.get_current().content_pack
	var center_z := pack.region_south + pack.region_length * 0.5
	var viewpoint := Vector3(pack.region_half_width * 0.58, 0.0, center_z)
	viewpoint.y = terrain.get_height_at_global(viewpoint) + 0.12
	terrain.ensure_area_at(viewpoint)
	level.player.global_position = viewpoint
	level.player.look_at(Vector3(pack.region_half_width * 0.82, viewpoint.y + 11.0, center_z), Vector3.UP)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	for _frame: int in 36:
		await get_tree().process_frame
	return get_viewport().get_texture().get_image().save_png(path)
