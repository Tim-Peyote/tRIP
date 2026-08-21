extends Node

const OUTPUT_PATH := "/tmp/trip_inventory_capture.png"


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 618, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	for definition_id: StringName in [&"ingredient.mooncap", &"ingredient.emberberry", &"item.spore_sight_brew"]:
		if ContentDB.get_definition(definition_id) != null:
			level.player.inventory.add_item(ItemInstance.new(definition_id))
	main.gameplay_hud.call("_toggle_inventory")
	for _frame: int in 5:
		await get_tree().process_frame
	var error := get_viewport().get_texture().get_image().save_png(OUTPUT_PATH)
	if error == OK:
		print("Inventory capture saved: %s" % OUTPUT_PATH)
	get_tree().quit(error)
