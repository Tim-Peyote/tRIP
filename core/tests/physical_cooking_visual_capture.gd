extends Node

const OUTPUT_PATH: String = "/tmp/trip_physical_cooking_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 95, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	var vessel := level.cooking_orchestrator.vessel
	vessel.add_water(1.0)
	vessel.add_ingredient(&"ingredient.mooncap", 1.0)
	vessel.heat_level = ThermalVesselState.HeatLevel.LOW
	vessel.temperature = 80.0
	vessel.stir_count = 2
	vessel.homogeneity = 0.76
	vessel.effective_target_duration = 12.0
	level.cooking_orchestrator.vessel_state_changed.emit(vessel)
	for _frame in 8:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error == OK:
		print("Physical cooking capture saved: %s" % OUTPUT_PATH)
	main.free()
	get_tree().quit(error)
