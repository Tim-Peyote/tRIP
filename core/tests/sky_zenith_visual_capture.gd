extends Node

const DAY_PATH := "/tmp/trip_sky_zenith_day.png"
const NIGHT_PATH := "/tmp/trip_sky_zenith_night.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 7117, true)
	for _frame: int in 16:
		await get_tree().process_frame
	var level := main.find_child("ExpeditionSession", true, false) as SessionController
	level.player.camera_rig.rotation.x = deg_to_rad(84.0)
	level.player.set("_look_pitch", deg_to_rad(84.0))
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.viewmodel.visible = false
	main.gameplay_hud.visible = false
	var error := await _capture(level, 0.35, DAY_PATH)
	if error == OK:
		error = await _capture(level, 0.9, NIGHT_PATH)
	if error == OK:
		print("Zenith sky captures saved.")
	get_tree().quit(error)


func _capture(level: SessionController, progress: float, path: String) -> Error:
	level.expedition_clock.set_progress(progress)
	for _frame: int in 16:
		await get_tree().process_frame
	return get_viewport().get_texture().get_image().save_png(path)
