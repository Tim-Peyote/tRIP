extends Node

var failures: Array[String] = []

func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 618, true)
	await get_tree().process_frame
	var level := main.find_child("ExpeditionSession", true, false) as SessionController
	var low := ItemInstance.new(&"ingredient.mooncap")
	low.quality = 0.2
	level.player.inventory.add_item(low)
	level.player.inventory.add_item(ItemInstance.new(&"ingredient.mooncap"))
	var hud := main.gameplay_hud
	hud.call("_toggle_inventory")
	hud.call("_select_inventory_stack", &"ingredient.mooncap", false)
	hud.call("_on_inventory_specimen_selected", 1)
	hud.call("_select_inventory_stack", &"ingredient.mooncap", false)
	check(hud.get("_selected_inventory_instance_id") == low.instance_id, "Reselect lost specimen")
	hud.call("_update_inventory_panel")
	check(hud.get("_selected_inventory_instance_id") == low.instance_id, "Refresh lost specimen")
	for card in hud.inventory_list.get_children():
		var button := card.get_node_or_null("Button") as InventoryDragButton
		if button == null:
			continue
		if button.drag_payload.get("definition_id") == &"ingredient.mooncap":
			check(button.drag_payload["instance_id"] == low.instance_id, "Drag differs from selected specimen")
		else:
			button.mouse_entered.emit()
			check(hud.get("_selected_inventory_instance_id") == low.instance_id, "Hover changed selection")
	get_window().content_scale_size = Vector2i.ZERO
	for resolution in [Vector2i(1280, 720), Vector2i(800, 600), Vector2i(640, 600)]:
		get_window().size = resolution
		for frame in 12:
			await get_tree().process_frame
		hud.call("_update_inventory_responsive_layout")
		for frame in 4:
			await get_tree().process_frame
		check(hud.inventory_detail_panel.is_visible_in_tree(), "Detail hidden at %s" % resolution)
		var viewport_rect := Rect2(Vector2.ZERO, hud.get_viewport_rect().size)
		check(viewport_rect.encloses(hud.inventory_panel.get_global_rect()), "Panel outside viewport at %s" % resolution)
		check(hud.inventory_panel.get_global_rect().encloses(hud.inventory_drop_button.get_global_rect()), "Drop outside panel at %s" % resolution)
		if DisplayServer.get_name() != "headless":
			get_viewport().get_texture().get_image().save_png("/tmp/trip_inventory_ux_%d.png" % resolution.x)
	hud.get_node("InventoryPanel/Margin/Layout/Header/Close").pressed.emit()
	check(not hud.inventory_panel.visible, "Close button failed")
	for failure in failures:
		push_error(failure)
	print("Inventory UX: PASS" if failures.is_empty() else "Inventory UX: FAIL")
	get_tree().quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
