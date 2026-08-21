extends Node

const OUTPUT_PATH: String = "/tmp/trip_road_laboratory_capture.png"
const METAMORPHOSIS_PATH: String = "/tmp/trip_road_laboratory_metamorph_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 94, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	var laboratory := level.get_road_laboratory()
	var cairn := laboratory.get_node("FirstRitualCairn") as RitualCairn
	var interactable := cairn.find_children("*", "InteractableComponent", true, false)[0] as InteractableComponent
	interactable.complete_interaction(level.player)
	var camp_position := laboratory.laboratory_position
	level.player.global_position = camp_position + Vector3(0, 1.0, 7.5)
	level.player.rotation.y = 0.0
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(0.58).timeout
	var metamorph_error := get_viewport().get_texture().get_image().save_png(METAMORPHOSIS_PATH)
	await get_tree().create_timer(1.05).timeout
	for _frame: int in 12:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error == OK:
		print("Road laboratory captures saved: %s · %s" % [METAMORPHOSIS_PATH, OUTPUT_PATH])
	main.free()
	get_tree().quit(metamorph_error if metamorph_error != OK else error)
