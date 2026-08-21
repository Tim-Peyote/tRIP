extends Node

const OUTPUT_PATH := "/tmp/trip_physical_weather_capture.png"


func _ready() -> void:
	var packed := load("res://app/main/main.tscn") as PackedScene
	var main := packed.instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 96, true)
	for _frame: int in 5:
		await get_tree().physics_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	level.get_weather().developer_set(WeatherOrchestrator.State.STORM)
	var player := level.player
	var body := level.physical_showcase.get_node("Полевой_ящик") as RigidBody3D
	var target := body.global_position
	var direction := Vector3(0, 0, -1)
	var destination := target + Vector3(0.65, 0, -2.2)
	destination.y = level.get_node("ExpeditionTerrain").get_height_at_global(destination) + 0.15
	player.global_position = destination
	player.look_at(Vector3(target.x, target.y, target.z), Vector3.UP)
	player.camera_rig.rotation.x = -0.08
	main.gameplay_hud.notice_label.visible = false
	player.interactor.set_process(false)
	main.gameplay_hud.call("_on_interaction_context_changed", {
		"key": "LMB",
		"title": "Полевой ящик",
		"action": "Удерживать · взять  |  ПКМ · вращать  |  F · бросить",
		"physical": true,
	})
	for _frame: int in 18:
		await get_tree().process_frame
	main.gameplay_hud.focus_card.show()
	print("Focus card visible: %s, rect: %s" % [main.gameplay_hud.focus_card.is_visible_in_tree(), main.gameplay_hud.focus_card.get_global_rect()])
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error == OK:
		print("Physical/weather capture saved: %s" % OUTPUT_PATH)
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(error)
