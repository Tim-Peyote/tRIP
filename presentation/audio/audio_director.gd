class_name AudioDirector
extends Node

signal snapshot_changed(snapshot_id: StringName)

const SNAPSHOT_FADE_SECONDS: float = 0.35

var _snapshot_id: StringName = &"default"


func set_snapshot(snapshot_id: StringName) -> void:
	if snapshot_id == _snapshot_id:
		return
	_snapshot_id = snapshot_id
	_apply_snapshot(snapshot_id)
	snapshot_changed.emit(snapshot_id)


func _apply_snapshot(snapshot_id: StringName) -> void:
	var targets: Dictionary = {
		&"default": {&"Music": 0.0, &"Ambience": 0.0, &"Perception": -6.0},
		&"pause": {&"Music": -4.0, &"Ambience": -10.0, &"Perception": -12.0},
		&"danger": {&"Music": -3.0, &"Ambience": -5.0, &"Perception": 0.0},
	}
	var values: Dictionary = targets.get(snapshot_id, targets[&"default"])
	var tween := create_tween().set_parallel(true)
	for bus_name: StringName in values:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			tween.tween_method(
				func(db: float) -> void: AudioServer.set_bus_volume_db(bus_index, db),
				AudioServer.get_bus_volume_db(bus_index),
				float(values[bus_name]),
				SNAPSHOT_FADE_SECONDS
			)

