extends Node

const OUTPUT_PATH: String = "/tmp/trip_cycle_result_capture.png"
const TEST_SLOT: int = 96


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", TEST_SLOT, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	var cap := ItemInstance.new(&"ingredient.mooncap")
	cap.quality = 1.0
	cap.processing_state[&"part"] = &"cap"
	level.objective_orchestrator.record_harvest(cap)
	level.objective_orchestrator.record_return(level.player)
	level.player.inventory.add_item(cap)
	level.knowledge_orchestrator.record_clue(&"ingredient.mooncap", &"observation.mooncap.silver_veins", 3)
	level.knowledge_orchestrator.record_clue(&"ingredient.mooncap", &"observation.mooncap.stem_ring", 3)
	level.knowledge_orchestrator.record_clue(&"ingredient.mooncap", &"observation.mooncap.pale_gills", 3)
	var tags: Array[StringName] = [&"fungus", &"perception"]
	level.cooking_orchestrator.perform_action(level.player, &"grind", &"ingredient.mooncap", tags, 1.0, 20.0, 8.0, &"ingredient.mooncap")
	level.cooking_orchestrator.perform_action(level.player, &"heat", &"ingredient.mooncap", tags, 1.0, 80.0, 24.0)
	for _frame in 8:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error == OK:
		print("Cycle result capture saved: %s" % OUTPUT_PATH)
	main.queue_free()
	await get_tree().process_frame
	SaveService.delete_slot(TEST_SLOT)
	get_tree().quit(error)
