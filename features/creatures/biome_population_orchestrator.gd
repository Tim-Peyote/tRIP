class_name BiomePopulationOrchestrator
extends Node3D

const ACTOR_SCRIPT = preload("res://features/creatures/biome_creature_actor.gd")

var _terrain: ExpeditionTerrain
var _player: Node3D
var _phase_orchestrator: WorldPhaseOrchestrator
var _definitions: Array[CreatureArchetypeDefinition] = []
var _populations: Dictionary[String, Node3D] = {}
var _elapsed: float = 0.0
var _enabled: bool = true
var _density_multiplier: float = 1.0


func setup(terrain: ExpeditionTerrain, player: Node3D, phase_orchestrator: WorldPhaseOrchestrator) -> void:
	_terrain = terrain
	_player = player
	_phase_orchestrator = phase_orchestrator
	_reload_definitions()
	_phase_orchestrator.phase_changed.connect(_on_phase_changed)
	_refresh_population(true)
	set_process(true)


func get_active_population_count() -> int:
	var total := 0
	for root: Node3D in _populations.values():
		if is_instance_valid(root): total += root.get_child_count()
	return total


func get_active_species_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for root: Node3D in _populations.values():
		if not is_instance_valid(root): continue
		for child: Node in root.get_children():
			if child is BiomeCreatureActor and (child as BiomeCreatureActor).definition != null:
				var species_id := (child as BiomeCreatureActor).definition.id
				if species_id not in result: result.append(species_id)
	return result


func developer_set_enabled(value: bool) -> void:
	_enabled = value
	if not value:
		_clear_population()
	else:
		_refresh_population(true)


func developer_cycle_density() -> float:
	_density_multiplier = 2.0 if _density_multiplier < 1.5 else (0.5 if _density_multiplier > 1.5 else 1.0)
	_clear_population()
	_refresh_population(true)
	return _density_multiplier


func developer_respawn() -> void:
	_clear_population()
	_refresh_population(true)


func _process(delta: float) -> void:
	if not _enabled: return
	_elapsed += delta
	if _elapsed >= 1.0:
		_elapsed = 0.0
		_refresh_population(false)


func _reload_definitions() -> void:
	_definitions.clear()
	for content: ContentDefinition in ContentDB.get_all():
		if content is CreatureArchetypeDefinition:
			_definitions.append(content as CreatureArchetypeDefinition)
	_definitions.sort_custom(func(a: CreatureArchetypeDefinition, b: CreatureArchetypeDefinition) -> bool: return a.id < b.id)


func _refresh_population(force: bool) -> void:
	if not _enabled or not is_instance_valid(_terrain) or not is_instance_valid(_player): return
	var alive: Dictionary[String, bool] = {}
	for chunk: StaticBody3D in _terrain.get_loaded_chunk_nodes():
		var coordinate: Vector2i = chunk.get_meta(&"chunk_coordinate", Vector2i.ZERO)
		if coordinate.y < 1: continue
		var key := "%d:%d" % [coordinate.x, coordinate.y]
		alive[key] = true
		if force or not _populations.has(key):
			_spawn_chunk_population(key, coordinate)
	for key: String in _populations.keys():
		if not alive.has(key):
			if is_instance_valid(_populations[key]): _populations[key].queue_free()
			_populations.erase(key)


func _spawn_chunk_population(key: String, coordinate: Vector2i) -> void:
	if _populations.has(key) and is_instance_valid(_populations[key]):
		_populations[key].queue_free()
	var root := Node3D.new()
	root.name = "Population_%s" % key.replace(":", "_")
	add_child(root)
	_populations[key] = root
	var phase_id := _terrain.get_world_phase()
	if phase_id == ExpeditionTerrain.PHASE_ORDINARY:
		phase_id = &"phase.ordinary"
	var candidates: Array[CreatureArchetypeDefinition] = []
	for definition: CreatureArchetypeDefinition in _definitions:
		if phase_id in definition.world_phase_ids:
			candidates.append(definition)
	if candidates.is_empty(): return
	var seed_value := int(_terrain.base_seed) * 1009 + coordinate.x * 73856093 + coordinate.y * 19349663 + String(phase_id).hash()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if rng.randf() > 0.58 * _density_multiplier: return
	var selected := _weighted_pick(candidates, rng)
	var group_size := clampi(rng.randi_range(selected.group_min, selected.group_max), 1, maxi(1, roundi(4.0 * _density_multiplier)))
	var center := Vector2((coordinate.x + rng.randf_range(0.18, 0.82)) * _terrain.chunk_size, (coordinate.y + rng.randf_range(0.18, 0.82)) * _terrain.chunk_size)
	for index: int in group_size:
		var actor := ACTOR_SCRIPT.new() as BiomeCreatureActor
		root.add_child(actor)
		var offset := Vector2(cos(float(index) * 2.4), sin(float(index) * 2.4)) * rng.randf_range(1.2, 3.8)
		var point := center + offset
		var height := _terrain.get_height_at_global(Vector3(point.x, 0, point.y))
		actor.global_position = Vector3(point.x, height + (2.8 if selected.body_plan == CreatureArchetypeDefinition.BodyPlan.BIRD else 0.08), point.y)
		actor.setup(selected, _player, _terrain, seed_value + index * 97)


func _weighted_pick(candidates: Array[CreatureArchetypeDefinition], rng: RandomNumberGenerator) -> CreatureArchetypeDefinition:
	var total := 0.0
	for definition: CreatureArchetypeDefinition in candidates: total += definition.spawn_weight
	var cursor := rng.randf() * maxf(total, 0.001)
	for definition: CreatureArchetypeDefinition in candidates:
		cursor -= definition.spawn_weight
		if cursor <= 0.0: return definition
	return candidates.back()


func _clear_population() -> void:
	for root: Node3D in _populations.values():
		if is_instance_valid(root): root.queue_free()
	_populations.clear()


func _on_phase_changed(_definition: WorldPhaseDefinition, _developer_override: bool) -> void:
	_clear_population()
	call_deferred("_refresh_population", true)
