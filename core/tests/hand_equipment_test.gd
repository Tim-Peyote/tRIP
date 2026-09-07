extends Node

func _ready() -> void:
	ContentDB.rebuild()
	var player := (load("res://features/player/player.tscn") as PackedScene).instantiate() as FirstPersonController
	add_child(player)
	var belt := player.toolbelt
	assert(not belt.is_equipped)
	assert(player.inventory.count(&"tool.field_knife") == 1.0)
	assert(not belt.equip(&"ingredient.mooncap"))
	assert(belt.equip(&"tool.field_knife"))
	assert(player.knife_viewmodel.visible and player.first_person_arm_rig.visible)
	belt.unequip()
	assert(not player.knife_viewmodel.visible and not player.first_person_arm_rig.visible)
	belt.equip(&"tool.field_knife")
	player.inventory.remove_one(&"tool.field_knife")
	assert(not belt.is_equipped and not player.first_person_arm_rig.visible)
	assert(not belt.equip(&"tool.field_knife"))
	assert(belt.equip(&"tool.spore_vial"))
	assert(player.vial_viewmodel.visible and not player.knife_viewmodel.visible)
	var saved := belt.to_save_data()
	belt.unequip()
	belt.apply_save_data(saved)
	assert(belt.is_equipped and belt.active_tool_id == &"tool.spore_vial")
	player.queue_free()
	await get_tree().process_frame
	print("TRip hand equipment test: PASS")
	get_tree().quit()
