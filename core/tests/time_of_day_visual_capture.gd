extends Node

const DAY_PATH := "/tmp/trip_taiga_day_capture.png"
const DUSK_PATH := "/tmp/trip_taiga_dusk_capture.png"
const NIGHT_PATH := "/tmp/trip_taiga_night_capture.png"
const DAWN_PATH := "/tmp/trip_taiga_dawn_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 117, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	var terrain := level.get_node("ExpeditionTerrain") as ExpeditionTerrain
	var route_z := 132.0
	var viewpoint := Vector3(float(terrain.call("_route_center_x", route_z)), 0.0, route_z)
	viewpoint.y = terrain.get_height_at_global(viewpoint) + 0.12
	terrain.ensure_area_at(viewpoint)
	level.player.global_position = viewpoint
	level.player.rotation.y = PI
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	level.get_biome_hazard().set_process(false)
	main.gameplay_hud.notice_timer.stop()
	main.gameplay_hud.notice_label.visible = false
	for _frame: int in 30:
		await get_tree().process_frame
	var error := await _capture(level, 0.08, DAY_PATH)
	if error == OK:
		error = await _capture(level, 0.65, DUSK_PATH)
	if error == OK:
		error = await _capture(level, 0.9, NIGHT_PATH)
	if error == OK:
		error = await _capture(level, 0.04, DAWN_PATH)
	if error == OK:
		print("Time-of-day captures saved.")
	get_tree().quit(error)


func _capture(level: ShelterLevel, progress: float, path: String) -> Error:
	level.expedition_clock.set_progress(progress)
	# Incremental sky radiance updates one cubemap face at a time. Let a complete
	# low-cost cycle settle before visual QA so captures match sustained gameplay.
	for _frame: int in 12:
		await get_tree().process_frame
	return get_viewport().get_texture().get_image().save_png(path)
