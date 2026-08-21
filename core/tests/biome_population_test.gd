extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ContentDB.rebuild()
	var creatures: Array[CreatureArchetypeDefinition] = []
	var npcs: Array[NPCArchetypeDefinition] = []
	for definition: ContentDefinition in ContentDB.get_all():
		if definition is CreatureArchetypeDefinition:
			creatures.append(definition as CreatureArchetypeDefinition)
		elif definition is NPCArchetypeDefinition:
			npcs.append(definition as NPCArchetypeDefinition)
	_expect(creatures.size() >= 16, "Fauna catalog is too small for the eight-world contract.")
	_expect(npcs.size() >= 8, "NPC catalog is too small for the narrative contract.")
	var phase_counts: Dictionary[StringName, int] = {}
	for creature: CreatureArchetypeDefinition in creatures:
		_expect(creature.validate().is_empty(), "Creature sheet failed validation: %s" % creature.id)
		_expect(creature.animation_states.size() >= 4, "Creature lacks an animation contract: %s" % creature.id)
		for phase_id: StringName in creature.world_phase_ids:
			phase_counts[phase_id] = int(phase_counts.get(phase_id, 0)) + 1
	for npc: NPCArchetypeDefinition in npcs:
		_expect(npc.validate().is_empty(), "NPC sheet failed validation: %s" % npc.id)
		_expect(npc.animation_states.size() >= 4 and npc.expression_states.size() >= 3, "NPC lacks performance states: %s" % npc.id)
	for phase_id: StringName in [
		&"phase.ordinary", &"phase.mycelial_choir", &"phase.crimson_hunt", &"phase.glass_frost",
		&"phase.ashen_silence", &"phase.mirror_flood", &"phase.root_dream", &"phase.distant_heart"
	]:
		_expect(int(phase_counts.get(phase_id, 0)) >= 2, "World has fewer than two authored fauna contracts: %s" % phase_id)

	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	main.call("_on_game_requested", 517, true)
	for _frame: int in 24:
		await get_tree().process_frame
	var level := main.find_child("ShelterLevel", true, false) as ShelterLevel
	_expect(level != null and level.get_biome_population() != null, "Biome population was not installed in the expedition level.")
	if level != null:
		var population := level.get_biome_population()
		population.developer_respawn()
		for _frame: int in 8: await get_tree().process_frame
		_expect(population.get_active_population_count() > 0, "Streamed chunks did not receive fauna.")
		for species_id: StringName in population.get_active_species_ids():
			var species := ContentDB.get_definition(species_id) as CreatureArchetypeDefinition
			_expect(species != null and &"phase.ordinary" in species.world_phase_ids, "Ordinary world spawned an incompatible species: %s" % species_id)
		level.world_phase_orchestrator.set_developer_phase(&"phase.glass_frost")
		for _frame: int in 12: await get_tree().process_frame
		population.developer_respawn()
		for _frame: int in 4: await get_tree().process_frame
		_expect(not population.get_active_species_ids().is_empty(), "Phase change did not repopulate fauna.")
		for species_id: StringName in population.get_active_species_ids():
			var species := ContentDB.get_definition(species_id) as CreatureArchetypeDefinition
			_expect(species != null and &"phase.glass_frost" in species.world_phase_ids, "Glass Frost spawned an incompatible species: %s" % species_id)
		var before_density := population.get_active_population_count()
		population.developer_cycle_density()
		for _frame: int in 8: await get_tree().process_frame
		_expect(population.get_active_population_count() >= before_density, "Developer high-density fauna mode did not increase or preserve the population.")
	main.queue_free()
	await get_tree().process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip biome population test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures: push_error(failure)
	print("TRip biome population test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
