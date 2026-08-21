extends Node

const OUTPUT_PATH := "/tmp/trip_herbarium_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 821, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	level.knowledge_orchestrator.observe(&"ingredient.mooncap")
	level.knowledge_orchestrator.record_clue(&"ingredient.mooncap", &"observation.mooncap.silver_veins", 3)
	level.knowledge_orchestrator.record_clue(&"ingredient.mooncap", &"observation.mooncap.stem_ring", 3)
	level.knowledge_orchestrator.observe(&"ingredient.false_mooncap")
	level.player.inventory.add_item(ItemInstance.new(&"ingredient.mooncap"))
	level.recipe_knowledge_orchestrator.discover_recipe(&"recipe.spore_sight_brew")
	main.gameplay_hud.call("_toggle_journal")
	for _frame: int in 5:
		await get_tree().process_frame
	var error := get_viewport().get_texture().get_image().save_png(OUTPUT_PATH)
	if error == OK:
		print("Herbarium capture saved: %s" % OUTPUT_PATH)
	get_tree().quit(error)
