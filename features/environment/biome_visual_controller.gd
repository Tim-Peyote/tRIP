class_name BiomeVisualController
extends Node

signal profile_changed(profile_id: StringName)
signal atmosphere_baseline_changed(fog_density: float, volumetric_density: float)

@export var shelter_profile: BiomeVisualProfile
@export var forest_profile: BiomeVisualProfile
@export var mycelial_profile: BiomeVisualProfile

var _environment: Environment
var _tween: Tween
var _sky_material: ProceduralSkyMaterial
var _primary_light: DirectionalLight3D
var _fill_light: DirectionalLight3D
var _base_profile: BiomeVisualProfile
var _metamorphosis_active: bool = false
var _world_override: BiomeVisualProfile
var _active_profile: BiomeVisualProfile
var _time_progress: float = 0.0


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
	# The environment lives under Main/Presentation while the biome key light lives
	# inside the active level. Resolve it from this controller's level first; the old
	# sibling-only lookup silently left every biome on the shelter's dim default.
	_primary_light = get_parent().find_child("MoonLight", true, false) as DirectionalLight3D
	if _primary_light == null and get_tree().current_scene != null:
		_primary_light = get_tree().current_scene.find_child("MoonLight", true, false) as DirectionalLight3D
	_configure_light_rig()
	_base_profile = shelter_profile
	apply_profile(shelter_profile, true)


func show_shelter(_actor: Node = null) -> void:
	_base_profile = shelter_profile
	apply_profile(_world_override if _world_override != null else _base_profile)


func setup_clock(clock: ExpeditionClock) -> void:
	if clock == null:
		return
	if not clock.time_changed.is_connected(set_time_progress):
		clock.time_changed.connect(set_time_progress)
	set_time_progress(clock.progress)


func set_time_progress(progress: float) -> void:
	_time_progress = clampf(progress, 0.0, 1.0)
	if _active_profile != null and _environment != null:
		_set_values(_active_profile)


func show_forest(_actor: Node = null) -> void:
	_base_profile = forest_profile
	apply_profile(_world_override if _world_override != null else _base_profile)


func show_forest_immediate() -> void:
	_base_profile = forest_profile
	apply_profile(_world_override if _world_override != null else _base_profile, true)


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
	_active_profile = profile
	var state := _time_state(profile)
	if _tween != null:
		_tween.kill()
	if immediate:
		_set_values(profile)
	else:
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(_environment, "background_color", state.background_color, 0.65)
		_tween.tween_property(_environment, "ambient_light_color", state.ambient_color, 0.65)
		_tween.tween_property(_environment, "ambient_light_energy", state.ambient_energy, 0.65)
		_tween.tween_property(_environment, "ambient_light_sky_contribution", profile.ambient_sky_contribution, 0.65)
		_tween.tween_property(_environment, "tonemap_exposure", state.exposure, 0.65)
		if is_instance_valid(_primary_light):
			_tween.tween_property(_primary_light, "light_color", state.light_color, 0.85)
			_tween.tween_property(_primary_light, "light_energy", state.light_energy, 0.85)
			_tween.tween_property(_primary_light, "rotation", state.light_rotation, 1.1)
		if is_instance_valid(_fill_light):
			_tween.tween_property(_fill_light, "light_color", state.fill_color, 0.85)
			_tween.tween_property(_fill_light, "light_energy", state.fill_energy, 0.85)
			_tween.tween_property(_fill_light, "rotation", state.fill_rotation, 1.1)
		_tween.tween_property(_environment, "fog_light_color", state.fog_color, 0.65)
		_tween.tween_property(_environment, "fog_density", state.fog_density, 0.65)
		_tween.tween_property(_environment, "fog_light_energy", profile.fog_light_energy, 0.65)
		_tween.tween_property(_environment, "volumetric_fog_density", state.volumetric_density, 0.65)
		_tween.tween_property(_environment, "volumetric_fog_albedo", state.volumetric_albedo, 0.65)
		_tween.tween_property(_environment, "volumetric_fog_emission", profile.volumetric_emission, 0.65)
		_tween.tween_property(_environment, "volumetric_fog_length", profile.volumetric_length, 0.65)
		if _sky_material != null:
			_tween.tween_property(_sky_material, "sky_top_color", state.sky_top_color, 1.2)
			_tween.tween_property(_sky_material, "sky_horizon_color", state.sky_horizon_color, 1.2)
			_tween.tween_property(_sky_material, "ground_bottom_color", profile.ground_bottom_color, 1.2)
			_tween.tween_property(_sky_material, "ground_horizon_color", profile.ground_horizon_color, 1.2)
			_tween.tween_property(_sky_material, "sky_energy_multiplier", state.sky_energy, 1.2)
	profile_changed.emit(profile.id)
	atmosphere_baseline_changed.emit(profile.fog_density, profile.volumetric_density)


func _set_values(profile: BiomeVisualProfile) -> void:
	var state := _time_state(profile)
	_environment.background_color = state.background_color
	_environment.ambient_light_color = state.ambient_color
	_environment.ambient_light_energy = state.ambient_energy
	_environment.ambient_light_sky_contribution = profile.ambient_sky_contribution
	_environment.tonemap_exposure = state.exposure
	if is_instance_valid(_primary_light):
		_primary_light.light_color = state.light_color
		_primary_light.light_energy = state.light_energy
		_primary_light.rotation = state.light_rotation
	if is_instance_valid(_fill_light):
		_fill_light.light_color = state.fill_color
		_fill_light.light_energy = state.fill_energy
		_fill_light.rotation = state.fill_rotation
	_environment.fog_light_color = state.fog_color
	_environment.fog_density = state.fog_density
	_environment.fog_light_energy = profile.fog_light_energy
	_environment.volumetric_fog_density = state.volumetric_density
	_environment.volumetric_fog_albedo = state.volumetric_albedo
	_environment.volumetric_fog_emission = profile.volumetric_emission
	_environment.volumetric_fog_length = profile.volumetric_length
	if _sky_material != null:
		_sky_material.sky_top_color = state.sky_top_color
		_sky_material.sky_horizon_color = state.sky_horizon_color
		_sky_material.ground_bottom_color = profile.ground_bottom_color
		_sky_material.ground_horizon_color = profile.ground_horizon_color
		_sky_material.sky_energy_multiplier = state.sky_energy


func _time_state(profile: BiomeVisualProfile) -> Dictionary:
	var dusk := smoothstep(0.28, 0.66, _time_progress)
	var night := smoothstep(0.68, 0.92, _time_progress)
	var dusk_top := profile.sky_top_color.lerp(profile.dusk_horizon_color, 0.22).darkened(0.32)
	var sky_top := profile.sky_top_color.lerp(dusk_top, dusk).lerp(profile.night_sky_top_color, night)
	var sky_horizon := profile.sky_horizon_color.lerp(profile.dusk_horizon_color, dusk).lerp(profile.night_sky_horizon_color, night)
	var ambient := profile.ambient_color.lerp(profile.dusk_horizon_color.darkened(0.58), dusk * 0.52).lerp(profile.night_ambient_color, night)
	var light_color := profile.primary_light_color.lerp(profile.dusk_light_color, dusk).lerp(profile.night_light_color, night)
	var dusk_rotation := Vector3(profile.primary_light_rotation.x * 0.72, profile.primary_light_rotation.y + 0.82, profile.primary_light_rotation.z)
	var light_rotation := profile.primary_light_rotation.lerp(dusk_rotation, dusk).lerp(profile.night_light_rotation, night)
	return {
		"background_color": profile.background_color.lerp(profile.night_sky_top_color, night * 0.82),
		"sky_top_color": sky_top,
		"sky_horizon_color": sky_horizon,
		"sky_energy": lerpf(profile.sky_energy, profile.sky_energy * 0.72, dusk) * lerpf(1.0, 0.58, night),
		"ambient_color": ambient,
		"ambient_energy": lerpf(profile.ambient_energy, profile.ambient_energy * 0.76, dusk) * lerpf(1.0, 0.68, night),
		"exposure": lerpf(profile.tonemap_exposure, profile.night_exposure, night),
		"light_color": light_color,
		"light_energy": lerpf(profile.primary_light_energy, profile.primary_light_energy * 0.68, dusk) * lerpf(1.0, profile.night_light_energy_scale, night),
		"light_rotation": light_rotation,
		"fill_color": ambient.lerp(sky_horizon, 0.38),
		"fill_energy": lerpf(profile.ambient_energy * 0.24, profile.ambient_energy * 0.16, night),
		"fill_rotation": Vector3(-0.24, light_rotation.y + PI, 0.06),
		"fog_color": profile.fog_color.lerp(profile.dusk_horizon_color.darkened(0.38), dusk * 0.72).lerp(profile.night_fog_color, night),
		"fog_density": profile.fog_density * lerpf(1.0, 1.22, night),
		"volumetric_density": profile.volumetric_density * lerpf(1.0, 1.34, night),
		"volumetric_albedo": profile.volumetric_albedo.lerp(profile.dusk_light_color, dusk * 0.26).lerp(profile.night_fog_color.lightened(0.18), night * 0.72),
	}


func _configure_light_rig() -> void:
	if is_instance_valid(_primary_light):
		_primary_light.shadow_enabled = true
		_primary_light.shadow_opacity = 0.86
		_primary_light.light_angular_distance = 1.15
		_primary_light.directional_shadow_max_distance = 150.0
		_primary_light.directional_shadow_blend_splits = true
		_primary_light.directional_shadow_fade_start = 0.86
		_primary_light.light_volumetric_fog_energy = 1.35
	_fill_light = DirectionalLight3D.new()
	_fill_light.name = "AtmosphericFillLight"
	_fill_light.shadow_enabled = false
	_fill_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_fill_light.light_volumetric_fog_energy = 0.18
	add_child(_fill_light)
	if _environment != null:
		_environment.fog_aerial_perspective = 0.72
		_environment.fog_sun_scatter = 0.32
		_environment.fog_sky_affect = 0.62
		_environment.volumetric_fog_anisotropy = 0.58
		_environment.volumetric_fog_sky_affect = 0.72
		_environment.volumetric_fog_temporal_reprojection_enabled = true
		_environment.volumetric_fog_temporal_reprojection_amount = 0.88


func get_primary_light() -> DirectionalLight3D:
	return _primary_light
