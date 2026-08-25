extends Node

const OUTPUT_PATH := "/tmp/trip_expedition_map_capture.png"
const MINIMAP_OUTPUT_PATH := "/tmp/trip_minimap_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 987, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	var terrain := level.get_expedition_terrain()
	var exploration := level.get_map_exploration()
	# Trace a deliberately irregular travelled route. The empty map around it must
	# remain unknown, making accidental full-world disclosure visible in the capture.
	for point: Vector2 in [Vector2(0, 16), Vector2(18, 54), Vector2(-12, 92), Vector2(-42, 138), Vector2(-25, 186), Vector2(8, 234)]:
		level.player.global_position = Vector3(point.x, terrain.get_height_at_global(Vector3(point.x, 0.0, point.y)) + 0.2, point.y)
		exploration.call("_reveal_around_player")
	for _frame: int in 2:
		await get_tree().process_frame
	var minimap_error := get_viewport().get_texture().get_image().save_png(MINIMAP_OUTPUT_PATH)
	main.gameplay_hud.call("_toggle_map")
	for _frame: int in 3:
		await get_tree().process_frame
	var error := get_viewport().get_texture().get_image().save_png(OUTPUT_PATH)
	if error == OK:
		print("Expedition map captures saved: %s · %s" % [MINIMAP_OUTPUT_PATH, OUTPUT_PATH])
	get_tree().quit(error if error != OK else minimap_error)
