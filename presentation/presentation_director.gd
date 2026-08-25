class_name PresentationDirector
extends Node

signal snapshot_applied(snapshot: PresentationSnapshot)

var _current := PresentationSnapshot.new()
var _target := PresentationSnapshot.new()


func _process(delta: float) -> void:
	_current.visual_intensity = move_toward(_current.visual_intensity, _target.visual_intensity, delta * 2.0)
	_current.perception = move_toward(_current.perception, _target.perception, delta * 1.5)
	_current.toxicity = move_toward(_current.toxicity, _target.toxicity, delta * 1.2)
	_current.danger = move_toward(_current.danger, _target.danger, delta * 2.5)
	_apply_global_parameters()


func apply_snapshot(snapshot: PresentationSnapshot) -> void:
	_target = snapshot.sanitized()
	snapshot_applied.emit(_target)


func set_visual_intensity(value: float) -> void:
	_target.visual_intensity = clampf(value, 0.0, 1.0)


func _apply_global_parameters() -> void:
	# A deliberately small stable contract for future world and screen shaders.
	RenderingServer.global_shader_parameter_set(&"trip_visual_intensity", _current.visual_intensity)
	RenderingServer.global_shader_parameter_set(&"trip_perception", _current.perception)
	RenderingServer.global_shader_parameter_set(&"trip_toxicity", _current.toxicity)
	RenderingServer.global_shader_parameter_set(&"trip_danger", _current.danger)
	# Day/night belongs to BiomeVisualController. Keeping a second writer here
	# reset the global to zero every frame and silently disabled moonlit materials.
