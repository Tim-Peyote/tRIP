extends Node

var _failures: Array[String] = []


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 941, true)
	await get_tree().process_frame
	var level := main.find_child("ExpeditionSession", true, false) as SessionController
	var panel := level.world_phase_developer_panel
	var player := level.player
	panel.set_panel_visible(true)
	_expect(panel.is_panel_visible(), "Developer panel did not open.")
	_expect(not bool(player.get("_gameplay_enabled")), "Gameplay remained enabled behind the developer panel.")
	var panel_control := panel.get("_panel") as Control
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_end := panel_control.position + panel_control.size
	_expect(panel_control.position.x >= 0.0 and panel_control.position.y >= 0.0 and panel_end.x <= viewport_size.x + 0.5 and panel_end.y <= viewport_size.y + 0.5, "Developer panel exceeds the viewport: panel %s..%s, viewport %s." % [panel_control.position, panel_end, viewport_size])

	var definitions := level.world_phase_orchestrator.get_definitions()
	_expect(definitions.size() == 8, "Developer world catalog does not expose all eight worlds.")
	for index: int in definitions.size():
		panel.call("_set_phase_by_index", index)
		_expect(level.world_phase_orchestrator.get_current() == definitions[index], "World shortcut %d selected the wrong phase." % (index + 1))
	panel.call("_cycle_phase", 1)
	panel.call("_cycle_phase", -1)

	for weather_state: int in WeatherOrchestrator.State.values():
		level.get_weather().developer_set(weather_state as WeatherOrchestrator.State)
		_expect(int(level.get_weather().state) == weather_state, "Weather mode %d did not activate." % weather_state)
	level.get_weather().developer_cycle()

	var vitals := player.vitals
	vitals.developer_set_condition(&"cold")
	_expect(float(vitals.get_snapshot()["core_temperature"]) < 36.0, "Cold physiology preset failed.")
	vitals.developer_set_condition(&"freezing")
	_expect(float(vitals.get_snapshot()["core_temperature"]) < 35.0, "Freezing physiology preset failed.")
	vitals.developer_set_condition(&"toxic")
	_expect(float(vitals.get_snapshot()["toxicity"]) > 0.8, "Toxic physiology preset failed.")
	vitals.developer_set_condition(&"spores")
	_expect(float(vitals.get_snapshot()["spore_load"]) > 0.8, "Spore physiology preset failed.")
	vitals.developer_set_condition(&"exhausted")
	_expect(float(vitals.get_snapshot()["stamina"]) <= 0.01, "Exhausted physiology preset failed.")
	vitals.developer_restore()
	_expect(float(vitals.get_snapshot()["health"]) > 0.0 and float(vitals.get_snapshot()["core_temperature"]) > 36.0, "Physiology restore failed.")

	var old_time := level.expedition_clock.progress
	panel.call("_cycle_time")
	_expect(not is_equal_approx(old_time, level.expedition_clock.progress), "Time-of-day shortcut did not advance the clock.")
	var old_seed := int(panel.get("_seed"))
	panel.call("_randomize_seed")
	_expect(int(panel.get("_seed")) != old_seed, "Seed randomizer did not change the seed.")
	var old_z := player.global_position.z
	panel.call("_teleport_route_ahead")
	_expect(player.global_position.z >= old_z + 80.0, "Route teleport did not move the player forward.")
	panel.call("_teleport_to_physics_lab")
	_expect(absf(player.global_position.z - 10.5) < 0.2, "Physics-lab teleport selected the wrong destination.")
	panel.call("_teleport_to_nearest", &"poi")
	_expect(player.global_position.is_finite(), "POI teleport produced an invalid position.")
	panel.call("_teleport_to_nearest", &"composition")
	_expect(player.global_position.is_finite(), "Composition teleport produced an invalid position.")

	panel.call("_set_phase_by_index", 0)
	var current := level.world_phase_orchestrator.get_current()
	var sample_id := current.content_pack.local_ingredient_ids[0]
	var old_count := player.inventory.count(sample_id)
	panel.call("_add_current_biome_sample")
	_expect(player.inventory.count(sample_id) > old_count, "Biome sample shortcut did not add an item.")
	_expect(level.get_world_progression().simulate_transition_formula(), "Transition-formula simulation failed.")
	_expect(level.get_biome_hazard().force_active() and level.get_biome_hazard().state == BiomeHazardOrchestrator.State.ACTIVE, "Hazard activation failed.")
	level.get_biome_hazard().developer_clear()
	_expect(level.get_biome_hazard().state == BiomeHazardOrchestrator.State.CALM, "Hazard clear failed.")
	level.get_biome_population().developer_respawn()
	var density := level.get_biome_population().developer_cycle_density()
	_expect(density in [0.5, 1.0, 2.0], "Fauna density cycle returned an invalid value.")
	_expect(level.get_road_laboratory().developer_toggle(false), "Instant laboratory toggle failed.")
	await get_tree().process_frame
	if level.get_road_laboratory().manifested:
		level.get_road_laboratory().developer_toggle(false)
		await get_tree().process_frame
	_expect(level.get_road_laboratory().developer_toggle(true), "Animated laboratory toggle failed.")
	_expect(level.get_road_laboratory().is_metamorphosing(), "Animated laboratory toggle did not start metamorphosis.")
	await get_tree().create_timer(2.2).timeout
	if level.get_road_laboratory().manifested:
		level.get_road_laboratory().developer_toggle(false)
	level.get_session_persistence().save_now(&"developer_test")
	_expect(SaveService.has_save(941), "Manual developer save failed.")

	var action_ids: Dictionary[StringName, bool] = {}
	for node: Node in panel_control.find_children("*", "Button", true, false):
		var action_id := StringName(node.get_meta(&"developer_action", &""))
		if action_id != &"":
			action_ids[action_id] = true
	for required: StringName in [&"transition_formula", &"resolve_mystery", &"hazard_start", &"hazard_clear", &"laboratory_animated", &"laboratory_instant", &"teleport_route", &"teleport_poi", &"teleport_composition", &"teleport_physics", &"grant_sample", &"cycle_time", &"save", &"fauna_respawn", &"fauna_density", &"randomize_seed", &"body_restore", &"body_cold", &"body_freezing", &"body_toxic", &"body_spores", &"body_exhausted", &"clear_override", &"weather_0", &"weather_1", &"weather_2", &"weather_3", &"weather_4"]:
		_expect(action_ids.has(required), "Developer UI is missing action: %s" % required)

	panel.set_panel_visible(false)
	_expect(bool(player.get("_gameplay_enabled")), "Gameplay was not restored after closing the developer panel.")
	main.queue_free()
	for _frame: int in 5:
		await get_tree().process_frame
	if _failures.is_empty():
		print("TRip developer panel test: PASS")
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		print("TRip developer panel test: FAIL (%d)" % _failures.size())
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
