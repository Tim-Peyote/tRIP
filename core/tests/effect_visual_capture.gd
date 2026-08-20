extends Node

const OUTPUT_PATH: String = "/tmp/trip_spore_sight_capture.png"


func _ready() -> void:
	var packed := load("res://app/main/main.tscn") as PackedScene
	var main := packed.instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 92, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	level.player.rotation.y = -0.58
	var effects: Array[StringName] = [&"effect.spore_sight"]
	main.effect_orchestrator.apply_effects(effects)
	for _frame in 12:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error == OK:
		print("Spore sight capture saved: %s" % OUTPUT_PATH)
	main.effect_orchestrator.clear()
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit(error)
