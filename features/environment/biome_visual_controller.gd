class_name BiomeVisualController
extends Node

signal profile_changed(profile_id: StringName)

@export var shelter_profile: BiomeVisualProfile
@export var forest_profile: BiomeVisualProfile

var _environment: Environment
var _tween: Tween


func setup(world_environment: WorldEnvironment) -> void:
	if world_environment == null or world_environment.environment == null:
		return
	_environment = world_environment.environment.duplicate(true)
	world_environment.environment = _environment
	apply_profile(shelter_profile, true)


func show_shelter(_actor: Node = null) -> void:
	apply_profile(shelter_profile)


func show_forest(_actor: Node = null) -> void:
	apply_profile(forest_profile)


func apply_profile(profile: BiomeVisualProfile, immediate: bool = false) -> void:
	if profile == null or _environment == null:
		return
	if _tween != null:
		_tween.kill()
	if immediate:
		_set_values(profile)
	else:
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(_environment, "background_color", profile.background_color, 0.65)
		_tween.tween_property(_environment, "ambient_light_color", profile.ambient_color, 0.65)
		_tween.tween_property(_environment, "ambient_light_energy", profile.ambient_energy, 0.65)
		_tween.tween_property(_environment, "fog_light_color", profile.fog_color, 0.65)
		_tween.tween_property(_environment, "fog_density", profile.fog_density, 0.65)
		_tween.tween_property(_environment, "fog_light_energy", profile.fog_light_energy, 0.65)
	profile_changed.emit(profile.id)


func _set_values(profile: BiomeVisualProfile) -> void:
	_environment.background_color = profile.background_color
	_environment.ambient_light_color = profile.ambient_color
	_environment.ambient_light_energy = profile.ambient_energy
	_environment.fog_light_color = profile.fog_color
	_environment.fog_density = profile.fog_density
	_environment.fog_light_energy = profile.fog_light_energy

