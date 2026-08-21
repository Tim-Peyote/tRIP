extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	InputBootstrap.ensure_defaults()
	for action: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"interact", &"inventory"]:
		var has_keyboard_binding := false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey and event.device < 0:
				has_keyboard_binding = true
		_expect(has_keyboard_binding, "Gameplay action has no normal-keyboard binding: %s" % action)
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.main_menu.call("_show_settings")
	await get_tree().process_frame
	var settings_panel := main.main_menu.settings_panel
	_expect(settings_panel.visible and settings_panel.get_global_rect().end.y <= 720.0, "Settings panel overflows the reference viewport.")
	_expect(settings_panel.get_node("Margin/Controls/HeadBobSlider") != null and settings_panel.get_node("Margin/Controls/FovSlider") != null, "Settings UI is missing first-person accessibility controls.")
	_expect((main.main_menu.get_node("SafeArea/Layout/NewGameButton") as Button).disabled, "Background menu remained interactive behind settings.")
	main.main_menu.call("_hide_settings")
	main.call("_on_game_requested", 41, true)
	await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	_expect(not level.forest_clearing.listener.visible and level.forest_clearing.listener.process_mode == Node.PROCESS_MODE_DISABLED, "Deprecated prototype Listener is still active in the opening clearing.")
	_expect(level.get_biome_population().get_active_population_count() == 0, "Fauna spawned inside the protected expedition opening.")
	level.expedition_clock.running = false
	var player := level.player
	player.inventory.add_item(ItemInstance.new(&"ingredient.mooncap"))
	player.inventory.add_item(ItemInstance.new(&"ingredient.mooncap"))
	var inventory_stacks := player.inventory.get_stacks()
	_expect(inventory_stacks.size() == 1 and is_equal_approx(float(inventory_stacks[0]["quantity"]), 2.0), "Inventory did not present duplicate samples as a readable stack.")
	player.set_gameplay_input_override_for_testing(true)
	var hud := main.gameplay_hud
	var start_position := player.global_position
	Input.action_press(&"move_forward")
	for _frame: int in 24:
		await get_tree().physics_frame
	Input.action_release(&"move_forward")
	_expect(player.global_position.distance_to(start_position) > 0.35, "First-person walking input did not move the character.")
	_expect(player.get_planar_speed() <= player.walk_speed + 0.35, "Walking accelerated beyond its authored gait.")
	Input.action_press(&"crouch")
	for _frame: int in 6:
		await get_tree().physics_frame
	_expect(player.is_crouched() and player.camera_rig.position.y < 1.5, "Crouch did not lower the first-person stance.")
	Input.action_release(&"crouch")
	player.set_gameplay_input_override_for_testing(false)

	var old_fov := float(SettingsService.get_value(&"video", &"fov", 75.0))
	SettingsService.set_value(&"video", &"fov", 82.0)
	_expect(is_equal_approx(player.camera.fov, 82.0), "FOV setting did not apply to the active camera.")
	SettingsService.set_value(&"video", &"fov", old_fov)

	# Field overlays are exclusive and own cursor/interactor state.
	hud.call("_toggle_inventory")
	_expect(hud.inventory_panel.visible, "Inventory did not open.")
	_expect(hud.inventory_list.get_child_count() == 1, "Inventory stack did not create one selectable UI card.")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Inventory did not release the cursor.")
	_expect(not player.interactor.is_processing(), "World interaction stayed active behind inventory.")
	hud.call("_toggle_journal")
	_expect(not hud.inventory_panel.visible and hud.get_node("JournalPanel").visible, "Journal did not replace inventory exclusively.")
	_expect(hud.close_top_overlay(), "Escape contract could not close the active field overlay.")
	_expect(not hud.has_modal_overlay(), "Closing the field overlay left another modal panel active.")
	_expect(player.interactor.is_processing(), "World interaction did not resume after closing UI.")
	player.inventory.remove_one(&"ingredient.mooncap")
	_expect(is_equal_approx(player.inventory.count(&"ingredient.mooncap"), 1.0), "Removing one stacked sample removed the whole stack.")
	hud.call("_on_biome_hazard_state_changed", BiomeHazardOrchestrator.State.ACTIVE, "ЯВЛЕНИЕ", "ИНСТРУКЦИЯ")
	hud.call("_on_spore_tide_state_changed", SporeTideOrchestrator.State.SURGE, "СПОРОВЫЙ ПРИЛИВ")
	hud.show_notice("ПРОВЕРКА НАРРАТИВНОГО СООБЩЕНИЯ")
	await get_tree().process_frame
	var hazard_rect := (hud.get_node("BiomeHazardLabel") as Control).get_global_rect()
	var spore_rect := (hud.get_node("SporeTideLabel") as Control).get_global_rect()
	var notice_rect := hud.notice_label.get_global_rect()
	_expect(not hazard_rect.intersects(spore_rect), "Generic hazard HUD overlaps the biome-specific pressure HUD.")
	_expect(not spore_rect.intersects(notice_rect), "Pressure HUD overlaps narrative notices.")

	# Gamepad look must not leak through a visible cursor/modal UI.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.action_press(&"look_right", 1.0)
	var yaw_before := player.rotation.y
	await get_tree().physics_frame
	_expect(is_equal_approx(player.rotation.y, yaw_before), "Gamepad rotated the player behind an open interface.")
	Input.action_release(&"look_right")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Bob fades by amplitude without rewinding its gait phase and snapping the camera.
	player.set("_bob_weight", 1.0)
	player.set("_bob_time", 1.0)
	player.call("_update_camera_feel", 0.1, 0.0)
	var moving_weight := float(player.get("_bob_weight"))
	var moving_phase := float(player.get("_bob_time"))
	player.call("_update_camera_feel", 0.05, 0.0)
	_expect(float(player.get("_bob_weight")) < moving_weight and moving_weight < 1.0, "Head bob did not fade after stopping.")
	_expect(float(player.get("_bob_time")) >= moving_phase, "Head bob rewound its phase and can snap on stop.")

	# The developer panel exposes all critical QA scenarios in one bounded viewport.
	var developer := level.world_phase_developer_panel
	developer.set_panel_visible(true)
	await get_tree().process_frame
	var panel := developer.find_child("WorldPhaseDeveloperPanel", true, false) as PanelContainer
	_expect(panel != null and panel.position.y + panel.size.y <= 720.0, "Developer panel overflows the reference viewport.")
	_expect(developer.find_children("*", "Button", true, false).size() >= 18, "Developer panel is missing rapid QA actions.")
	var laboratory := level.get_road_laboratory()
	_expect(laboratory.developer_toggle(false), "Developer laboratory toggle was unavailable.")
	_expect(laboratory.unlocked and laboratory.manifested, "Developer toggle did not unlock and manifest the laboratory.")
	level.get_biome_hazard().force_active()
	level.get_biome_hazard().developer_clear()
	_expect(level.get_biome_hazard().state == BiomeHazardOrchestrator.State.CALM and is_zero_approx(level.get_biome_hazard().exposure), "Developer hazard reset left pressure active.")
	var previous_z := player.global_position.z
	developer.call("_teleport_route_ahead")
	_expect(player.global_position.z >= previous_z + 80.0, "Route QA teleport did not advance streaming.")
	var previous_items := player.inventory.items.size()
	developer.call("_add_current_biome_sample")
	_expect(player.inventory.items.size() == previous_items + 1, "Developer sample injection did not reach inventory.")
	developer.set_panel_visible(false)
	_expect(not panel.visible, "Developer panel remained visible after closing.")

	main.call("_pause_game")
	_expect(get_tree().paused and hud.pause_panel.visible, "Pause UI did not own the paused state.")
	main.call("_resume_game")
	_expect(not get_tree().paused and not hud.pause_panel.visible, "Resume did not restore gameplay state.")

	main.queue_free()
	await get_tree().process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip interface and developer QA test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip interface and developer QA test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
