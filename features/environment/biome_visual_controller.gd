class_name BiomeVisualController
extends Node

signal profile_changed(profile_id: StringName)

@export var shelter_profile: BiomeVisualProfile
@export var forest_profile: BiomeVisualProfile
@export var mycelial_profile: BiomeVisualProfile

var _environment: Environment
var _tween: Tween
var _sky_material: ProceduralSkyMaterial
var _base_profile: BiomeVisualProfile
var _metamorphosis_active: bool = false
var _world_override: BiomeVisualProfile


func setup(world_environment: WorldEnvironment) -> void:
	if world_environment == null or world_environment.environment == null:
		return
	_environment = world_environment.environment.duplicate(true)
	world_environment.environment = _environment
	if _environment.sky != null:
		_environment.sky = _environment.sky.duplicate(true)
		if _environment.sky.sky_material is ProceduralSkyMaterial:
			_sky_material = _environment.sky.sky_material.duplicate(true) as ProceduralSkyMaterial
			_environment.sky.sky_material = _sky_material
	_base_profile = shelter_profile
	apply_profile(shelter_profile, true)


func show_shelter(_actor: Node = null) -> void:
	_base_profile = shelter_profile
	apply_profile(_world_override if _world_override != null else _base_profile)


func show_forest(_actor: Node = null) -> void:
	_base_profile = forest_profile
	apply_profile(_world_override if _world_override != null else _base_profile)


func set_metamorphosis(active: bool) -> void:
	if _metamorphosis_active == active:
		return
	_metamorphosis_active = active
	if active:
		set_world_override(mycelial_profile)
	else:
		clear_world_override()


func set_world_override(profile: BiomeVisualProfile) -> void:
	_world_override = profile
	apply_profile(profile)


func clear_world_override() -> void:
	_world_override = null
	apply_profile(_base_profile)


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
		_tween.tween_property(_environment, "volumetric_fog_density", profile.volumetric_density, 0.65)
		_tween.tween_property(_environment, "volumetric_fog_albedo", profile.volumetric_albedo, 0.65)
		_tween.tween_property(_environment, "volumetric_fog_emission", profile.volumetric_emission, 0.65)
		_tween.tween_property(_environment, "volumetric_fog_length", profile.volumetric_length, 0.65)
		if _sky_material != null:
			_tween.tween_property(_sky_material, "sky_top_color", profile.sky_top_color, 1.2)
			_tween.tween_property(_sky_material, "sky_horizon_color", profile.sky_horizon_color, 1.2)
			_tween.tween_property(_sky_material, "sky_energy_multiplier", profile.sky_energy, 1.2)
	profile_changed.emit(profile.id)


func _set_values(profile: BiomeVisualProfile) -> void:
	_environment.background_color = profile.background_color
	_environment.ambient_light_color = profile.ambient_color
	_environment.ambient_light_energy = profile.ambient_energy
	_environment.fog_light_color = profile.fog_color
	_environment.fog_density = profile.fog_density
	_environment.fog_light_energy = profile.fog_light_energy
	_environment.volumetric_fog_density = profile.volumetric_density
	_environment.volumetric_fog_albedo = profile.volumetric_albedo
	_environment.volumetric_fog_emission = profile.volumetric_emission
	_environment.volumetric_fog_length = profile.volumetric_length
	if _sky_material != null:
		_sky_material.sky_top_color = profile.sky_top_color
		_sky_material.sky_horizon_color = profile.sky_horizon_color
		_sky_material.sky_energy_multiplier = profile.sky_energy
