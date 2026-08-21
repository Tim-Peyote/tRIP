extends Node

const ORDINARY_PATH: String = "/tmp/trip_streaming_world_capture.png"
const ALTERED_PATH: String = "/tmp/trip_world_metamorph_capture.png"
const DEVELOPER_PATH: String = "/tmp/trip_world_developer_capture.png"
const CRIMSON_PATH: String = "/tmp/trip_world_crimson_capture.png"
const FROST_PATH: String = "/tmp/trip_world_frost_capture.png"
const ASHEN_PATH: String = "/tmp/trip_world_ashen_capture.png"
const MIRROR_PATH: String = "/tmp/trip_world_mirror_capture.png"
const ROOT_PATH: String = "/tmp/trip_world_root_capture.png"
const HEART_PATH: String = "/tmp/trip_world_heart_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 117, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	level.biome_visual_controller.apply_profile(level.biome_visual_controller.forest_profile, true)
	var terrain := level.get_node("ExpeditionTerrain") as ExpeditionTerrain
	# The comparison camera sits on the seed-specific route after it has left the
	# authored camp corridor and begun to wander through streamed terrain.
	var route_z := 132.0
	var viewpoint := Vector3(float(terrain.call("_route_center_x", route_z)), 0, route_z)
	viewpoint.y = terrain.get_height_at_global(viewpoint) + 0.12
	terrain.ensure_area_at(viewpoint)
	level.player.global_position = viewpoint
	level.player.rotation.y = 3.14159
	for _frame in 28:
		await get_tree().process_frame
	# World comparison captures validate composition and biome readability. The
	# narrative notice has its own UI coverage and must not hide the focal plane.
	main.gameplay_hud.notice_timer.stop()
	main.gameplay_hud.notice_label.visible = false
	await get_tree().process_frame
	main.gameplay_hud.notice_label.visible = false
	var ordinary := get_viewport().get_texture().get_image()
	var first_error := ordinary.save_png(ORDINARY_PATH)
	level.world_phase_orchestrator.set_developer_phase(&"phase.mycelial_choir")
	terrain.call("_set_phase_amount", 1.0)
	level.biome_visual_controller.apply_profile(level.biome_visual_controller.mycelial_profile, true)
	_reground_viewpoint(level, terrain)
	for _frame in 6:
		await get_tree().process_frame
	var altered := get_viewport().get_texture().get_image()
	var second_error := altered.save_png(ALTERED_PATH)
	level.world_phase_developer_panel.set_panel_visible(true)
	await get_tree().process_frame
	var developer := get_viewport().get_texture().get_image()
	var third_error := developer.save_png(DEVELOPER_PATH)
	level.world_phase_developer_panel.set_panel_visible(false)
	var showcase_error := await _capture_phase(level, terrain, &"phase.crimson_hunt", CRIMSON_PATH)
	if showcase_error == OK:
		showcase_error = await _capture_phase(level, terrain, &"phase.glass_frost", FROST_PATH)
	if showcase_error == OK:
		showcase_error = await _capture_phase(level, terrain, &"phase.ashen_silence", ASHEN_PATH)
	if showcase_error == OK:
		showcase_error = await _capture_phase(level, terrain, &"phase.mirror_flood", MIRROR_PATH)
	if showcase_error == OK:
		showcase_error = await _capture_phase(level, terrain, &"phase.root_dream", ROOT_PATH)
	if showcase_error == OK:
		showcase_error = await _capture_phase(level, terrain, &"phase.distant_heart", HEART_PATH)
	if first_error == OK and second_error == OK and third_error == OK:
		print("Streaming world captures saved.")
	main.queue_free()
	await get_tree().process_frame
	var final_error := first_error if first_error != OK else second_error
	if final_error == OK:
		final_error = third_error
	if final_error == OK:
		final_error = showcase_error
	get_tree().quit(final_error)


func _capture_phase(level: ShelterLevel, terrain: ExpeditionTerrain, phase_id: StringName, path: String) -> Error:
	level.world_phase_orchestrator.set_developer_phase(phase_id)
	terrain.call("_set_phase_amount", 1.0)
	level.biome_visual_controller.apply_profile(level.world_phase_orchestrator.get_current().visual_profile, true)
	_reground_viewpoint(level, terrain)
	for _frame in 8:
		await get_tree().process_frame
	return get_viewport().get_texture().get_image().save_png(path)


func _reground_viewpoint(level: ShelterLevel, terrain: ExpeditionTerrain) -> void:
	var viewpoint := level.player.global_position
	viewpoint.y = terrain.get_height_at_global(viewpoint) + 0.12
	terrain.ensure_area_at(viewpoint)
	level.player.global_position = viewpoint
	level.player.velocity = Vector3.ZERO
