extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var terrain := ExpeditionTerrain.new()
	add_child(terrain)
	var visuals := BiomeVisualController.new()
	add_child(visuals)
	var environment_node := WorldEnvironment.new()
	environment_node.environment = Environment.new()
	add_child(environment_node)
	visuals.shelter_profile = load("res://presentation/biomes/shelter_visual_profile.tres") as BiomeVisualProfile
	visuals.forest_profile = load("res://presentation/biomes/forest_visual_profile.tres") as BiomeVisualProfile
	visuals.mycelial_profile = load("res://presentation/biomes/mycelial_visual_profile.tres") as BiomeVisualProfile
	visuals.setup(environment_node)
	var orchestrator := WorldPhaseOrchestrator.new()
	add_child(orchestrator)
	orchestrator.setup(terrain, visuals)
	var definitions := orchestrator.get_definitions()
	_expect(definitions.size() == 8, "World catalog must contain exactly eight designed phases.")
	var ids: Dictionary[StringName, bool] = {}
	for index in definitions.size():
		var definition: WorldPhaseDefinition = definitions[index]
		_expect(definition.order == index, "World phases are not ordered for progression.")
		_expect(not ids.has(definition.id), "World phase IDs are not unique.")
		_expect(definition.visual_profile != null, "World phase has no visual profile: %s" % definition.id)
		ids[definition.id] = true
		orchestrator.set_developer_phase(definition.id)
		_expect(orchestrator.get_current() == definition, "Developer switching failed for %s" % definition.id)
		var expected_terrain_phase := ExpeditionTerrain.PHASE_ORDINARY if definition.is_baseline() else definition.id
		_expect(terrain.get_world_phase() == expected_terrain_phase, "Terrain did not receive phase %s" % definition.id)
	orchestrator.clear_developer_override()
	orchestrator.apply_gameplay_channels({&"spore_vision": 1.0})
	_expect(orchestrator.get_current().id == &"phase.mycelial_choir", "Real consumable channel did not select the mycelial world.")
	_expect(not orchestrator.is_developer_override_active(), "Gameplay phase remained in developer override mode.")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip world phase test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip world phase test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
