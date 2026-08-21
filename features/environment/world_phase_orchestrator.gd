class_name WorldPhaseOrchestrator
extends Node

signal phase_changed(definition: WorldPhaseDefinition, developer_override: bool)

const DEFINITION_PATHS: PackedStringArray = [
	"res://content/world_phases/ordinary_world.tres",
	"res://content/world_phases/mycelial_choir.tres",
	"res://content/world_phases/crimson_hunt.tres",
	"res://content/world_phases/glass_frost.tres",
	"res://content/world_phases/ashen_silence.tres",
	"res://content/world_phases/mirror_flood.tres",
	"res://content/world_phases/root_dream.tres",
	"res://content/world_phases/distant_heart.tres",
]

var _definitions: Array[WorldPhaseDefinition] = []
var _by_id: Dictionary[StringName, WorldPhaseDefinition] = {}
var _terrain: ExpeditionTerrain
var _visuals: BiomeVisualController
var _current: WorldPhaseDefinition
var _developer_override: bool = false
var _last_gameplay_channels: Dictionary[StringName, float] = {}
var _story_phase_id: StringName = &"phase.ordinary"


func _ready() -> void:
	_load_catalog()


func setup(terrain: ExpeditionTerrain, visuals: BiomeVisualController) -> void:
	_terrain = terrain
	_visuals = visuals
	if _definitions.is_empty():
		_load_catalog()
	set_phase(&"phase.ordinary")


func get_definitions() -> Array[WorldPhaseDefinition]:
	return _definitions.duplicate()


func get_current() -> WorldPhaseDefinition:
	return _current


func is_developer_override_active() -> bool:
	return _developer_override


func set_developer_phase(phase_id: StringName) -> void:
	_developer_override = true
	set_phase(phase_id, true)


func clear_developer_override() -> void:
	_developer_override = false
	_apply_gameplay_channels_without_override(_last_gameplay_channels)


func set_story_phase(phase_id: StringName) -> void:
	if not _by_id.has(phase_id):
		return
	_story_phase_id = phase_id
	if not _developer_override:
		set_phase(phase_id, false)


func get_story_phase_id() -> StringName:
	return _story_phase_id


func apply_gameplay_channels(channels: Dictionary[StringName, float]) -> void:
	_last_gameplay_channels = channels.duplicate()
	if _developer_override:
		return
	_apply_gameplay_channels_without_override(channels)


func _apply_gameplay_channels_without_override(channels: Dictionary[StringName, float]) -> void:
	var selected := _by_id.get(_story_phase_id) as WorldPhaseDefinition
	if selected == null:
		selected = _by_id.get(&"phase.ordinary") as WorldPhaseDefinition
	for definition: WorldPhaseDefinition in _definitions:
		if definition.effect_channel != &"" and float(channels.get(definition.effect_channel, 0.0)) > 0.1:
			if selected == null or definition.order > selected.order:
				selected = definition
	if selected != null:
		set_phase(selected.id, false)


func set_phase(phase_id: StringName, from_developer: bool = false) -> void:
	var definition := _by_id.get(phase_id) as WorldPhaseDefinition
	if definition == null:
		push_warning("Unknown world phase: %s" % phase_id)
		return
	if _current == definition and from_developer == _developer_override:
		return
	_current = definition
	if _terrain != null:
		_terrain.apply_world_phase(definition)
	if _visuals != null:
		if definition.is_baseline():
			_visuals.clear_world_override()
		else:
			_visuals.set_world_override(definition.visual_profile)
	phase_changed.emit(definition, _developer_override)


func _load_catalog() -> void:
	_definitions.clear()
	_by_id.clear()
	for path: String in DEFINITION_PATHS:
		var definition := load(path) as WorldPhaseDefinition
		if definition == null:
			push_error("World phase definition failed to load: %s" % path)
			continue
		_definitions.append(definition)
		_by_id[definition.id] = definition
	_definitions.sort_custom(func(a: WorldPhaseDefinition, b: WorldPhaseDefinition) -> bool: return a.order < b.order)
