class_name MapExplorationOrchestrator
extends Node

signal exploration_changed(phase_id: StringName)
signal active_phase_changed(phase_id: StringName)

const CELL_SIZE: float = 12.0
const REVEAL_RADIUS: float = 28.0
const UPDATE_INTERVAL: float = 0.22

var _player: Node3D
var _terrain: ExpeditionTerrain
var _phases: WorldPhaseOrchestrator
var _active_phase_id: StringName = &"phase.ordinary"
var _elapsed: float = 0.0
# phase -> "x:z" -> { height, zone }
var _explored: Dictionary = {}


func setup(player: Node3D, terrain: ExpeditionTerrain, phases: WorldPhaseOrchestrator) -> void:
	_player = player
	_terrain = terrain
	_phases = phases
	if phases.get_current() != null:
		_active_phase_id = phases.get_current().id
	phases.phase_changed.connect(_on_phase_changed)
	set_process(true)
	_reveal_around_player()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < UPDATE_INTERVAL:
		return
	_elapsed = 0.0
	_reveal_around_player()


func get_active_phase_id() -> StringName:
	return _active_phase_id


func get_cell_size() -> float:
	return CELL_SIZE


func get_explored_cells(phase_id: StringName = &"") -> Dictionary:
	var selected := phase_id if phase_id != &"" else _active_phase_id
	return (_explored.get(String(selected), {}) as Dictionary).duplicate(true)


func get_explored_ratio(phase_id: StringName = &"") -> float:
	if _terrain == null:
		return 0.0
	var bounds := _terrain.get_map_bounds()
	var approximate_total := maxf(1.0, bounds.size.x * bounds.size.y * 0.78 / (CELL_SIZE * CELL_SIZE))
	return clampf(float(get_explored_cells(phase_id).size()) / approximate_total, 0.0, 1.0)


func to_save_data() -> Dictionary:
	var phases_data: Dictionary = {}
	for phase_key: Variant in _explored:
		var entries: Array[Dictionary] = []
		var cells := _explored[phase_key] as Dictionary
		for cell_key: Variant in cells:
			var coordinate := _decode_cell(String(cell_key))
			var sample := cells[cell_key] as Dictionary
			entries.append({
				"x": coordinate.x,
				"z": coordinate.y,
				"height": float(sample.get("height", 0.0)),
				"zone": int(sample.get("zone", ExpeditionTerrain.LandscapeZone.DENSE_FOREST)),
			})
		phases_data[String(phase_key)] = entries
	return {"phases": phases_data}


func apply_save_data(data: Dictionary) -> void:
	_explored.clear()
	var phases_data := data.get("phases", {}) as Dictionary
	for phase_key: Variant in phases_data:
		var cells: Dictionary = {}
		for raw_entry: Variant in phases_data[phase_key] as Array:
			var entry := raw_entry as Dictionary
			var coordinate := Vector2i(int(entry.get("x", 0)), int(entry.get("z", 0)))
			cells[_encode_cell(coordinate)] = {
				"height": float(entry.get("height", 0.0)),
				"zone": int(entry.get("zone", ExpeditionTerrain.LandscapeZone.DENSE_FOREST)),
			}
		_explored[String(phase_key)] = cells
	exploration_changed.emit(_active_phase_id)
	_reveal_around_player()


func _reveal_around_player() -> void:
	if not is_instance_valid(_player) or _terrain == null:
		return
	var center := Vector2(_player.global_position.x, _player.global_position.z)
	if not _terrain.is_inside_playable_region(_player.global_position, 0.02):
		return
	var phase_key := String(_active_phase_id)
	var cells: Dictionary = _explored.get(phase_key, {}) as Dictionary
	var center_cell := Vector2i(floori(center.x / CELL_SIZE), floori(center.y / CELL_SIZE))
	var cell_radius := ceili(REVEAL_RADIUS / CELL_SIZE)
	var changed := false
	for z_offset: int in range(-cell_radius, cell_radius + 1):
		for x_offset: int in range(-cell_radius, cell_radius + 1):
			var coordinate := center_cell + Vector2i(x_offset, z_offset)
			var world_point := Vector2((coordinate.x + 0.5) * CELL_SIZE, (coordinate.y + 0.5) * CELL_SIZE)
			if world_point.distance_to(center) > REVEAL_RADIUS:
				continue
			var world_position := Vector3(world_point.x, 0.0, world_point.y)
			if not _terrain.is_inside_playable_region(world_position):
				continue
			var cell_key := _encode_cell(coordinate)
			if cells.has(cell_key):
				continue
			var context := _terrain.get_environment_context(world_position)
			cells[cell_key] = {
				"height": float(context.get("height", 0.0)),
				"zone": int(context.get("zone", ExpeditionTerrain.LandscapeZone.DENSE_FOREST)),
			}
			changed = true
	_explored[phase_key] = cells
	if changed:
		exploration_changed.emit(_active_phase_id)


func _on_phase_changed(definition: WorldPhaseDefinition, _developer_override: bool) -> void:
	if definition == null:
		return
	_active_phase_id = definition.id
	active_phase_changed.emit(_active_phase_id)
	_reveal_around_player()


func _encode_cell(coordinate: Vector2i) -> String:
	return "%d:%d" % [coordinate.x, coordinate.y]


func _decode_cell(value: String) -> Vector2i:
	var parts := value.split(":", false, 1)
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))
