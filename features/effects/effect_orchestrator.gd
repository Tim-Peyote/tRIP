class_name EffectOrchestrator
extends Node

signal gameplay_channels_changed(channels: Dictionary[StringName, float])
signal effect_started(effect_id: StringName, duration: float)
signal effect_ended(effect_id: StringName)

var _presentation: PresentationDirector
var _active: Dictionary[StringName, float] = {}
var _last_gameplay_channels: Dictionary[StringName, float] = {}


func setup(presentation: PresentationDirector) -> void:
	_presentation = presentation
	set_process(true)


func apply_effects(effect_ids: Array[StringName], _display_name: String = "") -> void:
	for effect_id: StringName in effect_ids:
		var definition := ContentDB.get_definition(effect_id) as EffectDefinition
		if definition == null:
			push_error("Unknown effect id: %s" % effect_id)
			continue
		for cancelled_id: StringName in definition.cancels_effect_ids:
			if _active.erase(cancelled_id):
				effect_ended.emit(cancelled_id)
		_active[effect_id] = definition.duration_seconds
		effect_started.emit(effect_id, definition.duration_seconds)
	_rebuild_channels()


func clear() -> void:
	for effect_id: StringName in _active.keys():
		effect_ended.emit(effect_id)
	_active.clear()
	_rebuild_channels()


func has_effect(effect_id: StringName) -> bool:
	return _active.has(effect_id)


func get_gameplay_channels() -> Dictionary[StringName, float]:
	return _last_gameplay_channels.duplicate()


func _process(delta: float) -> void:
	if _active.is_empty():
		return
	var ended: Array[StringName] = []
	for effect_id: StringName in _active:
		_active[effect_id] = float(_active[effect_id]) - delta
		if float(_active[effect_id]) <= 0.0:
			ended.append(effect_id)
	for effect_id: StringName in ended:
		_active.erase(effect_id)
		effect_ended.emit(effect_id)
	if not ended.is_empty():
		_rebuild_channels()


func _rebuild_channels() -> void:
	var gameplay: Dictionary[StringName, float] = {}
	var presentation: Dictionary[StringName, float] = {}
	for effect_id: StringName in _active:
		var definition := ContentDB.get_definition(effect_id) as EffectDefinition
		if definition == null:
			continue
		_accumulate_channels(gameplay, definition.gameplay_channels)
		_accumulate_channels(presentation, definition.presentation_channels)
	if gameplay != _last_gameplay_channels:
		_last_gameplay_channels = gameplay.duplicate()
		gameplay_channels_changed.emit(gameplay)
	if _presentation != null:
		var snapshot := PresentationSnapshot.new()
		snapshot.visual_intensity = float(SettingsService.get_value(&"accessibility", &"visual_intensity", 1.0))
		snapshot.perception = float(presentation.get(&"perception", 0.0))
		snapshot.toxicity = maxf(float(gameplay.get(&"toxicity", 0.0)), float(presentation.get(&"toxicity", 0.0)))
		_presentation.apply_snapshot(snapshot)


func _accumulate_channels(target: Dictionary[StringName, float], source: Dictionary[StringName, float]) -> void:
	for channel: StringName in source:
		target[channel] = clampf(float(target.get(channel, 0.0)) + source[channel], 0.0, 1.0)
