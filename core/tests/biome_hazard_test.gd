extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ContentDB.rebuild()
	var level := (load("res://core/tests/fixtures/legacy_expedition_fixture.tscn") as PackedScene).instantiate() as LegacyExpeditionFixture
	add_child(level)
	await get_tree().process_frame
	level.expedition_clock.running = false
	var ids: Dictionary[StringName, bool] = {}
	var rules: Dictionary[int, bool] = {}
	var visuals: Dictionary[int, bool] = {}
	for phase: WorldPhaseDefinition in level.world_phase_orchestrator.get_definitions():
		var hazard := phase.hazard_profile
		_expect(hazard != null, "World %s has no biome hazard profile." % phase.id)
		if hazard == null:
			continue
		_expect(hazard.validate().is_empty(), "Hazard %s failed its content validation." % hazard.id)
		ids[hazard.id] = true
		rules[int(hazard.counter_rule)] = true
		visuals[int(hazard.visual_family)] = true
	_expect(ids.size() == 8, "World phases do not expose eight distinct hazard definitions.")
	_expect(rules.size() == 5, "Biome hazards do not exercise all five counterplay rules.")
	_expect(visuals.size() == 8, "Biome hazards do not expose eight distinct visual families.")

	var terrain := level.get_node("ExpeditionTerrain") as ExpeditionTerrain
	var controller := level.get_biome_hazard()
	level.world_phase_orchestrator.set_developer_phase(&"phase.crimson_hunt")
	controller.activate_session()
	controller.set_process(false)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	var test_position := Vector3(float(terrain.call("_route_center_x", 120.0)), 0.0, 120.0)
	test_position.y = terrain.get_height_at_global(test_position) + 0.18
	level.player.global_position = test_position
	controller.call("_process", 0.1)
	controller.force_active()
	var hazard_audio := controller.get("_audio") as AudioStreamPlayer3D
	_expect(hazard_audio != null and hazard_audio.stream is AudioStreamOggVorbis, "Biome hazard is not using recorded OGG ambience.")
	level.player.velocity = Vector3.ZERO
	for _step: int in 3:
		controller.call("_process", 1.0)
	var unsafe_exposure := controller.exposure
	_expect(unsafe_exposure > 0.4, "Ignoring the Crimson keep-moving rule did not build exposure.")
	level.player.velocity = Vector3(1.2, 0.0, 0.0)
	for _step: int in 2:
		controller.call("_process", 1.0)
	_expect(controller.exposure < unsafe_exposure, "Correct Crimson counterplay did not reduce exposure.")
	controller.exposure = 0.98
	level.player.velocity = Vector3.ZERO
	controller.call("_process", 1.0)
	_expect(is_equal_approx(controller.exposure, 0.34), "Hazard overwhelm did not reset exposure to its recoverable state.")
	var save_data := controller.to_save_data()
	_expect(save_data.has("last_safe_position") and save_data.has("exposure"), "Biome hazard persistence payload is incomplete.")

	level.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip biome hazard test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip biome hazard test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
