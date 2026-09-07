class_name WeatherOrchestrator
extends Node3D

signal state_changed(state: int, title: String, intensity: float)
signal wetness_changed(value: float)
signal lightning_struck(origin: Vector3, strength: float)

enum State { CLEAR, DRIZZLE, STORM, FOG, SNOW }

const RAIN_AMBIENCE := preload("res://assets/third_party/open_game_art_audio/rain_long.ogg")
const WIND_SOFT := preload("res://assets/third_party/open_game_art_audio/wind_soft.ogg")
const WIND_STRONG := preload("res://assets/third_party/open_game_art_audio/wind_strong.ogg")
const THUNDERCLAP := preload("res://assets/third_party/open_game_art_audio/thunderclap.wav")
const WEATHER_WEIGHTS: Dictionary[int, Array] = {
	BiomeContentPack.EcologyFamily.ALTAI_TAIGA: [38.0, 26.0, 10.0, 20.0, 6.0],
	BiomeContentPack.EcologyFamily.MYCELIAL_KARST: [16.0, 28.0, 8.0, 45.0, 3.0],
	BiomeContentPack.EcologyFamily.CRIMSON_STEPPE: [55.0, 8.0, 20.0, 14.0, 3.0],
	BiomeContentPack.EcologyFamily.GLACIAL_CIRQUE: [18.0, 4.0, 14.0, 22.0, 42.0],
	BiomeContentPack.EcologyFamily.ASHEN_TUNDRA: [24.0, 2.0, 8.0, 38.0, 28.0],
	BiomeContentPack.EcologyFamily.MIRROR_WETLAND: [12.0, 38.0, 22.0, 26.0, 2.0],
	BiomeContentPack.EcologyFamily.ROOT_CAVERN: [20.0, 18.0, 2.0, 58.0, 2.0],
	BiomeContentPack.EcologyFamily.HEART_PLATEAU: [34.0, 16.0, 14.0, 28.0, 8.0],
}
const ECOLOGY_TEMPERATURES: Dictionary[int, float] = {
	BiomeContentPack.EcologyFamily.ALTAI_TAIGA: 11.0,
	BiomeContentPack.EcologyFamily.MYCELIAL_KARST: 8.0,
	BiomeContentPack.EcologyFamily.CRIMSON_STEPPE: 19.0,
	BiomeContentPack.EcologyFamily.GLACIAL_CIRQUE: -13.0,
	BiomeContentPack.EcologyFamily.ASHEN_TUNDRA: -5.0,
	BiomeContentPack.EcologyFamily.MIRROR_WETLAND: 9.0,
	BiomeContentPack.EcologyFamily.ROOT_CAVERN: 6.0,
	BiomeContentPack.EcologyFamily.HEART_PLATEAU: 4.0,
}

var state: State = State.CLEAR
var intensity: float = 0.0
var wetness: float = 0.0
var wind: Vector3 = Vector3.ZERO
var automatic: bool = true

var _player: FirstPersonController
var _terrain: ExpeditionTerrain
var _environment: Environment
var _precipitation: GPUParticles3D
var _precipitation_depth: GPUParticles3D
var _lightning: DirectionalLight3D
var _rain_audio: AudioStreamPlayer
var _wind_audio: AudioStreamPlayer
var _thunder_audio: AudioStreamPlayer3D
var _environment_tween: Tween
var _rng := RandomNumberGenerator.new()
var _state_time: float = 0.0
var _next_change: float = 105.0
var _lightning_time: float = 8.0
var _reactive_tick: float = 0.0
var _base_fog_density: float = 0.012
var _base_volumetric_density: float = 0.012
var _base_contrast: float = 1.0
var _base_saturation: float = 1.0
var _base_glow_intensity: float = 0.52
var _ecology_family: int = BiomeContentPack.EcologyFamily.ALTAI_TAIGA
var _local_context: Dictionary = {
	"zone": ExpeditionTerrain.LandscapeZone.DENSE_FOREST,
	"zone_id": &"dense_forest",
	"altitude": 0.0,
	"moisture": 0.45,
	"exposure": 0.5,
	"can_snow": false,
	"forest_shelter": 0.5,
}
var _context_tick: float = 0.0
var _wind_target := Vector3(0.35, 0.0, 0.12)
var _wind_shift_time: float = 0.0
var _last_local_intensity: float = -1.0


func setup(world_environment: WorldEnvironment, player: FirstPersonController, terrain: ExpeditionTerrain = null) -> void:
	_player = player
	_terrain = terrain
	_environment = world_environment.environment if world_environment != null else null
	if _environment != null:
		_base_fog_density = _environment.fog_density
		_base_volumetric_density = _environment.volumetric_fog_density
		_base_contrast = _environment.adjustment_contrast
		_base_saturation = _environment.adjustment_saturation
		_base_glow_intensity = _environment.glow_intensity
	_rng.seed = 98317
	_sample_local_context(true)
	_build_precipitation()
	_build_lightning()
	_build_audio()
	RenderingServer.global_shader_parameter_set(&"trip_wind_vector", Vector3(0.35, 0.0, 0.12))
	RenderingServer.global_shader_parameter_set(&"trip_wind_strength", 0.0)
	RenderingServer.global_shader_parameter_set(&"trip_cloud_coverage", 0.28)
	RenderingServer.global_shader_parameter_set(&"trip_cloud_storm", 0.0)
	set_weather(State.CLEAR, 0.0, true)


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set(&"trip_wind_strength", 0.0)
	if _environment_tween != null:
		_environment_tween.kill()
		_environment_tween = null
	for player: AudioStreamPlayer in [_rain_audio, _wind_audio]:
		if player != null:
			player.stop()
			player.stream = null
	if _thunder_audio != null:
		_thunder_audio.stop()
		_thunder_audio.stream = null


func set_run_seed(value: int) -> void:
	_rng.seed = 98317 ^ value
	_next_change = _rng.randf_range(90.0, 170.0)


func apply_world_phase(definition: WorldPhaseDefinition, _developer_override: bool = false) -> void:
	if definition != null and definition.content_pack != null:
		set_ecology_family(definition.content_pack.ecology_family)


func set_ecology_family(value: int) -> void:
	_ecology_family = clampi(value, 0, 7)
	_state_time = 0.0
	_next_change = _rng.randf_range(45.0, 95.0)
	var weights := get_weather_weights()
	# Do not carry an ecologically impossible condition into the next world
	# (for example snowfall over the mirror wetland). Such a transition adopts
	# the biome's signature weather as part of the metamorphosis.
	if float(weights[state]) <= 4.0:
		var dominant_state := 0
		for index: int in range(1, weights.size()):
			if float(weights[index]) > float(weights[dominant_state]):
				dominant_state = index
		set_weather(dominant_state as State, 0.72)


func get_weather_weights() -> Array:
	var weights := (WEATHER_WEIGHTS.get(_ecology_family, WEATHER_WEIGHTS[BiomeContentPack.EcologyFamily.ALTAI_TAIGA]) as Array).duplicate()
	if not is_instance_valid(_terrain):
		return weights
	var zone := int(_local_context.get("zone", ExpeditionTerrain.LandscapeZone.DENSE_FOREST))
	var altitude := float(_local_context.get("altitude", 0.0))
	var moisture := float(_local_context.get("moisture", 0.45))
	match zone:
		ExpeditionTerrain.LandscapeZone.RIVER_VALLEY, ExpeditionTerrain.LandscapeZone.BASIN:
			weights[State.DRIZZLE] *= lerpf(1.1, 1.55, moisture)
			weights[State.FOG] *= lerpf(1.2, 1.8, moisture)
			weights[State.STORM] *= 0.78
		ExpeditionTerrain.LandscapeZone.DENSE_FOREST:
			weights[State.DRIZZLE] *= 1.18
			weights[State.FOG] *= 1.32
			weights[State.STORM] *= 0.84
		ExpeditionTerrain.LandscapeZone.HIGHLAND, ExpeditionTerrain.LandscapeZone.BOUNDARY:
			weights[State.STORM] *= 1.34
			weights[State.SNOW] *= lerpf(1.15, 1.8, altitude)
			weights[State.FOG] *= 1.12
		ExpeditionTerrain.LandscapeZone.ALPINE:
			weights[State.STORM] *= 1.42
			weights[State.SNOW] *= 2.25
			weights[State.DRIZZLE] *= 0.34
	if not bool(_local_context.get("can_snow", false)):
		var displaced_snow := float(weights[State.SNOW])
		weights[State.SNOW] = 0.15
		weights[State.DRIZZLE] += displaced_snow * 0.42
		weights[State.FOG] += displaced_snow * 0.28
	return weights


func _process(delta: float) -> void:
	if _player == null:
		return
	global_position = _player.global_position
	RenderingServer.global_shader_parameter_set(&"trip_wind_vector", wind.normalized() if wind.length_squared() > 0.01 else Vector3(0.35, 0.0, 0.12))
	RenderingServer.global_shader_parameter_set(&"trip_wind_strength", clampf(wind.length() / 8.5, 0.0, 1.0))
	_state_time += delta
	_reactive_tick += delta
	_context_tick += delta
	if _context_tick >= 1.0:
		_context_tick = 0.0
		_sample_local_context(false)
	_update_wind(delta)
	_update_surface_state(delta)
	_update_lightning(delta)
	_update_audio(delta)
	if automatic and _state_time >= _next_change:
		_choose_next_weather()
	if _reactive_tick >= 0.5:
		_reactive_tick = 0.0
		_apply_to_reactive_objects()


func set_weather(next_state: State, strength: float = 1.0, immediate: bool = false) -> void:
	if next_state == State.SNOW and automatic and is_instance_valid(_terrain) and not bool(_local_context.get("can_snow", false)):
		next_state = State.DRIZZLE if float(_local_context.get("moisture", 0.0)) >= 0.42 else State.FOG
	state = next_state
	intensity = clampf(strength, 0.0, 1.0)
	_state_time = 0.0
	_next_change = _rng.randf_range(90.0, 170.0)
	_configure_particles()
	_apply_cloud_state()
	_apply_environment(immediate)
	if _player != null:
		_player.set_weather_modifiers(_target_wetness(), wind.length(), get_ambient_temperature())
	state_changed.emit(state, get_state_title(), intensity)


func developer_cycle() -> void:
	automatic = false
	set_weather(((int(state) + 1) % State.size()) as State, 0.9)


func developer_set(next_state: State) -> void:
	automatic = false
	set_weather(next_state, 0.9)


func developer_resume_automatic() -> void:
	automatic = true
	_state_time = _next_change


func set_atmosphere_baseline(fog_density: float, volumetric_density: float) -> void:
	_base_fog_density = fog_density
	_base_volumetric_density = volumetric_density
	_apply_environment(false)


func set_postprocess_baseline(contrast: float, saturation: float, glow_intensity: float) -> void:
	_base_contrast = contrast
	_base_saturation = saturation
	_base_glow_intensity = glow_intensity
	_apply_environment(false)


func get_state_title() -> String:
	return ["Ясно", "Мелкий дождь", "Гроза", "Туман", "Снег"][state]


func get_debug_text() -> String:
	return "%s · %s · %d°C · локально %d%% · земля %d%% · ветер %.1f м/с · %s" % [
		get_state_title(), String(_local_context.get("zone_id", &"dense_forest")), roundi(get_ambient_temperature()), roundi(get_local_intensity() * 100.0), roundi(wetness * 100.0), wind.length(),
		"авто" if automatic else "ручной режим",
	]


func get_ambient_temperature() -> float:
	var result := float(ECOLOGY_TEMPERATURES.get(_ecology_family, 10.0))
	result -= float(_local_context.get("altitude", 0.0)) * 11.0
	match state:
		State.STORM: result -= 5.0 * intensity
		State.DRIZZLE: result -= 2.5 * intensity
		State.FOG: result -= 1.5 * intensity
		State.SNOW: result -= 7.0 * intensity
		_: result += 1.5 * (1.0 - intensity)
	return result


func _choose_next_weather() -> void:
	var weights := get_weather_weights()
	var total := 0.0
	for weight: float in weights:
		total += maxf(weight, 0.0)
	var roll := _rng.randf() * total
	var next_state := State.CLEAR
	for index: int in weights.size():
		roll -= maxf(float(weights[index]), 0.0)
		if roll <= 0.0:
			next_state = index as State
			break
	var strength_range := {
		State.CLEAR: Vector2(0.0, 0.35),
		State.DRIZZLE: Vector2(0.35, 0.78),
		State.STORM: Vector2(0.68, 1.0),
		State.FOG: Vector2(0.42, 0.92),
		State.SNOW: Vector2(0.45, 1.0),
	}[next_state] as Vector2
	set_weather(next_state, _rng.randf_range(strength_range.x, strength_range.y))


func _target_wetness() -> float:
	var local_strength := get_local_intensity()
	match state:
		State.DRIZZLE: return 0.58 * local_strength
		State.STORM: return local_strength
		State.FOG: return 0.28 * local_strength
		State.SNOW: return 0.38 * local_strength
		_: return 0.0


func get_local_context() -> Dictionary:
	return _local_context.duplicate()


func get_local_intensity() -> float:
	if not is_instance_valid(_terrain):
		return intensity
	var exposure := float(_local_context.get("exposure", 0.5))
	var shelter := float(_local_context.get("forest_shelter", 0.0))
	var moisture := float(_local_context.get("moisture", 0.45))
	var modifier := 1.0
	match state:
		State.DRIZZLE:
			modifier = lerpf(0.88, 1.14, moisture) * (1.0 - shelter * 0.3)
		State.STORM:
			modifier = lerpf(0.76, 1.22, exposure) * (1.0 - shelter * 0.24)
		State.FOG:
			modifier = lerpf(0.78, 1.26, moisture) * lerpf(1.08, 0.9, exposure)
		State.SNOW:
			modifier = lerpf(0.72, 1.25, exposure) * (1.0 - shelter * 0.34)
	return clampf(intensity * modifier, 0.0, 1.0)


func _sample_local_context(immediate: bool) -> void:
	if not is_instance_valid(_terrain) or not is_instance_valid(_player):
		return
	var previous_zone := int(_local_context.get("zone", -1))
	_local_context = _terrain.get_environment_context(_player.global_position)
	var zone_changed := previous_zone != int(_local_context.get("zone", -1))
	if state == State.SNOW and not bool(_local_context.get("can_snow", false)) and automatic:
		set_weather(State.DRIZZLE if float(_local_context.get("moisture", 0.0)) >= 0.42 else State.FOG, intensity, immediate)
		return
	var local_strength := get_local_intensity()
	var strength_changed := absf(local_strength - _last_local_intensity) >= 0.08
	_last_local_intensity = local_strength
	if zone_changed or strength_changed:
		_configure_particles()
		_apply_environment(immediate)
	if zone_changed:
		state_changed.emit(state, get_state_title(), intensity)


func _update_wind(delta: float) -> void:
	_wind_shift_time -= delta
	if _wind_shift_time <= 0.0:
		_wind_shift_time = _rng.randf_range(6.0, 15.0) if state == State.STORM else _rng.randf_range(18.0, 42.0)
		var current_angle := atan2(_wind_target.z, _wind_target.x)
		var maximum_turn := 1.0 if state == State.STORM else 0.48
		var next_angle := current_angle + _rng.randf_range(-maximum_turn, maximum_turn)
		var exposure := float(_local_context.get("exposure", 0.5))
		var shelter := float(_local_context.get("forest_shelter", 0.0))
		var weather_speed := lerpf(0.35, 8.5, get_local_intensity())
		if state == State.CLEAR:
			weather_speed *= 0.42
		elif state == State.FOG:
			weather_speed *= 0.16
		elif state == State.SNOW:
			weather_speed *= 0.78
		var local_speed := weather_speed * lerpf(0.62, 1.28, exposure) * (1.0 - shelter * 0.52)
		_wind_target = Vector3(cos(next_angle), 0.0, sin(next_angle)) * local_speed
	wind = wind.move_toward(_wind_target, delta * (2.8 if state == State.STORM else 0.72))
	for layer: GPUParticles3D in [_precipitation, _precipitation_depth]:
		var process := layer.process_material as ParticleProcessMaterial if is_instance_valid(layer) else null
		if process != null:
			process.direction = Vector3(wind.x * (0.12 if state == State.SNOW else 0.065), -0.4 if state == State.SNOW else -1.0, wind.z * (0.12 if state == State.SNOW else 0.065)).normalized()


func _update_surface_state(delta: float) -> void:
	var target := _target_wetness()
	var rate := (0.055 + get_local_intensity() * 0.08) if target > wetness else 0.012
	var next := move_toward(wetness, target, rate * delta)
	if not is_equal_approx(next, wetness):
		wetness = next
		wetness_changed.emit(wetness)
		if _player != null:
			_player.set_weather_modifiers(wetness, wind.length(), get_ambient_temperature())


func _apply_to_reactive_objects() -> void:
	if get_tree() == null:
		return
	for node: Node in get_tree().get_nodes_in_group(&"weather_reactive"):
		if node is PhysicalPropertyComponent:
			var properties := node as PhysicalPropertyComponent
			if _target_wetness() > 0.0:
				properties.apply_precipitation(0.018 * get_local_intensity())
			else:
				properties.dry(0.006)


func _build_precipitation() -> void:
	var rig := get_node_or_null("WeatherRig")
	if rig == null:
		rig = (load("res://features/weather/weather_rig.tscn") as PackedScene).instantiate()
		add_child(rig)
	_precipitation = rig.get_node("LocalPrecipitation") as GPUParticles3D
	_precipitation_depth = rig.get_node("WeatherDepthLayer") as GPUParticles3D


func _configure_particles() -> void:
	if _precipitation == null or _precipitation_depth == null:
		return
	var snow_is_local := state != State.SNOW or bool(_local_context.get("can_snow", false))
	var local_strength := get_local_intensity()
	var should_emit := state in [State.DRIZZLE, State.STORM, State.SNOW] and local_strength > 0.02 and snow_is_local
	_precipitation.emitting = should_emit
	_precipitation_depth.emitting = should_emit
	var initial_direction := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-0.8, 0.8)).normalized()
	if initial_direction.length_squared() < 0.1:
		initial_direction = Vector3(0.9, 0.0, 0.25)
	_wind_target = initial_direction * lerpf(0.4, 8.5, local_strength)
	if state == State.FOG:
		_wind_target *= 0.15
	if wind.length_squared() < 0.01:
		wind = _wind_target
	_configure_particle_layer(_precipitation, false, local_strength)
	_configure_particle_layer(_precipitation_depth, true, local_strength)


func _configure_particle_layer(layer: GPUParticles3D, depth_layer: bool, local_strength: float) -> void:
	layer.amount = roundi(lerpf(120.0, 480.0, local_strength) if depth_layer else lerpf(240.0, 1050.0, local_strength))
	var prefix := "res://features/weather/%s_%s" % ["snow" if state == State.SNOW else "rain", "far" if depth_layer else "near"]
	var process := (load(prefix + "_process.tres") as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
	process.direction = Vector3(wind.x * 0.065, -1.0, wind.z * 0.065).normalized() if state != State.SNOW else Vector3(wind.x * 0.12, -0.4, wind.z * 0.12).normalized()
	layer.process_material = process
	layer.draw_pass_1 = load(prefix + "_mesh.tres") as Mesh


func _apply_environment(immediate: bool) -> void:
	if _environment == null:
		return
	var local_strength := get_local_intensity()
	var fog_target := _base_fog_density
	var volumetric_target := _base_volumetric_density
	# Clear weather uses the cheap depth fog. The full froxel volume is reserved
	# for conditions where shafts and suspended moisture are actually visible.
	var volumetric_enabled := state != State.CLEAR and local_strength > 0.05
	_environment.volumetric_fog_enabled = volumetric_enabled
	if not volumetric_enabled:
		volumetric_target = 0.0
	var brightness_target := 1.0
	var contrast_target := _base_contrast
	var saturation_target := _base_saturation
	var glow_target := _base_glow_intensity
	var aerial_target := 0.42
	var scatter_target := 0.18
	var anisotropy_target := 0.45
	match state:
		State.FOG:
			fog_target = maxf(fog_target, lerpf(0.014, 0.034, local_strength))
			volumetric_target = maxf(volumetric_target, lerpf(0.012, 0.038, local_strength))
			brightness_target = lerpf(1.0, 0.9, local_strength)
			saturation_target = lerpf(_base_saturation, _base_saturation * 0.78, local_strength)
			contrast_target = lerpf(_base_contrast, _base_contrast * 0.92, local_strength)
			aerial_target = 0.9
			anisotropy_target = 0.42
		State.DRIZZLE:
			fog_target = maxf(fog_target, 0.009 * local_strength)
			volumetric_target = maxf(volumetric_target, 0.01 * local_strength)
			brightness_target = lerpf(1.0, 0.88, local_strength)
			saturation_target = lerpf(_base_saturation, _base_saturation * 0.86, local_strength)
			scatter_target = 0.2
		State.STORM:
			fog_target = maxf(fog_target, 0.014)
			volumetric_target = maxf(volumetric_target, 0.018)
			brightness_target = lerpf(0.88, 0.7, local_strength)
			saturation_target = lerpf(_base_saturation * 0.88, _base_saturation * 0.68, local_strength)
			contrast_target = lerpf(_base_contrast, _base_contrast * 0.9, local_strength)
			glow_target = lerpf(_base_glow_intensity, _base_glow_intensity * 1.22, local_strength)
			aerial_target = 0.84
			scatter_target = 0.08
			anisotropy_target = 0.7
		State.SNOW:
			fog_target = maxf(fog_target, 0.011)
			volumetric_target = maxf(volumetric_target, 0.014)
			brightness_target = lerpf(1.0, 1.04, local_strength)
			saturation_target = lerpf(_base_saturation, _base_saturation * 0.84, local_strength)
			aerial_target = 0.86
	var local_zone := int(_local_context.get("zone", ExpeditionTerrain.LandscapeZone.DENSE_FOREST))
	var local_altitude := float(_local_context.get("altitude", 0.0))
	var local_moisture := float(_local_context.get("moisture", 0.45))
	if local_zone in [ExpeditionTerrain.LandscapeZone.RIVER_VALLEY, ExpeditionTerrain.LandscapeZone.BASIN]:
		fog_target *= lerpf(1.08, 1.42, local_moisture)
		volumetric_target *= lerpf(1.06, 1.3, local_moisture)
	elif local_zone == ExpeditionTerrain.LandscapeZone.DENSE_FOREST:
		fog_target *= 1.12
	elif local_zone in [ExpeditionTerrain.LandscapeZone.HIGHLAND, ExpeditionTerrain.LandscapeZone.BOUNDARY]:
		fog_target *= lerpf(1.0, 1.18, local_altitude)
	elif local_zone == ExpeditionTerrain.LandscapeZone.ALPINE and state == State.FOG:
		# The highest ridges can rise above a valley cloud deck instead of receiving
		# the same opaque screen fog as the lowlands.
		fog_target *= lerpf(0.78, 0.52, local_altitude)
		volumetric_target *= lerpf(0.86, 0.58, local_altitude)
	if immediate:
		_environment.fog_density = fog_target
		_environment.volumetric_fog_density = volumetric_target
		_environment.adjustment_brightness = brightness_target
		_environment.adjustment_contrast = contrast_target
		_environment.adjustment_saturation = saturation_target
		_environment.glow_intensity = glow_target
		_environment.fog_aerial_perspective = aerial_target
		_environment.fog_sun_scatter = scatter_target
		_environment.volumetric_fog_anisotropy = anisotropy_target
	else:
		if _environment_tween != null:
			_environment_tween.kill()
		_environment_tween = create_tween().set_parallel(true)
		_environment_tween.tween_property(_environment, "fog_density", fog_target, 2.8)
		_environment_tween.tween_property(_environment, "volumetric_fog_density", volumetric_target, 2.8)
		_environment_tween.tween_property(_environment, "adjustment_brightness", brightness_target, 2.8)
		_environment_tween.tween_property(_environment, "adjustment_contrast", contrast_target, 2.8)
		_environment_tween.tween_property(_environment, "adjustment_saturation", saturation_target, 2.8)
		_environment_tween.tween_property(_environment, "glow_intensity", glow_target, 2.8)
		_environment_tween.tween_property(_environment, "fog_aerial_perspective", aerial_target, 2.8)
		_environment_tween.tween_property(_environment, "fog_sun_scatter", scatter_target, 2.8)
		_environment_tween.tween_property(_environment, "volumetric_fog_anisotropy", anisotropy_target, 2.8)


func _apply_cloud_state() -> void:
	var coverage := 0.28
	var storm_amount := 0.0
	match state:
		State.DRIZZLE:
			coverage = lerpf(0.48, 0.72, intensity)
			storm_amount = intensity * 0.28
		State.STORM:
			coverage = lerpf(0.76, 0.96, intensity)
			storm_amount = intensity
		State.FOG:
			coverage = lerpf(0.52, 0.78, intensity)
			storm_amount = intensity * 0.36
		State.SNOW:
			coverage = lerpf(0.58, 0.86, intensity)
			storm_amount = intensity * 0.5
		_:
			coverage = lerpf(0.18, 0.34, intensity)
	RenderingServer.global_shader_parameter_set(&"trip_cloud_coverage", coverage)
	RenderingServer.global_shader_parameter_set(&"trip_cloud_storm", storm_amount)


func _build_lightning() -> void:
	_lightning = $WeatherRig/LightningFlash


func _update_lightning(delta: float) -> void:
	if state != State.STORM:
		_lightning.light_energy = move_toward(_lightning.light_energy, 0.0, delta * 8.0)
		return
	_lightning_time -= delta
	if _lightning_time > 0.0:
		_lightning.light_energy = move_toward(_lightning.light_energy, 0.0, delta * 7.0)
		return
	_lightning_time = _rng.randf_range(4.5, 13.0)
	_lightning.light_energy = lerpf(2.5, 6.0, intensity)
	var strike_origin := _player.global_position + Vector3(_rng.randf_range(-35, 35), 0, _rng.randf_range(-35, 35))
	_spawn_lightning_bolt(strike_origin, intensity)
	lightning_struck.emit(strike_origin, intensity)
	_schedule_thunder(strike_origin, intensity)
	for node: Node in get_tree().get_nodes_in_group(&"weather_reactive"):
		if node is PhysicalPropertyComponent:
			var parent := node.get_parent() as Node3D
			if parent != null and parent.global_position.distance_to(strike_origin) < 7.0:
				(node as PhysicalPropertyComponent).apply_electricity(intensity)


func _spawn_lightning_bolt(strike_origin: Vector3, strength: float) -> void:
	var bolt := Node3D.new()
	bolt.name = "LightningBolt"
	bolt.top_level = true
	add_child(bolt)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.72, 0.84, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.48, 0.68, 1.0)
	material.emission_energy_multiplier = lerpf(5.0, 10.0, strength)
	var points: Array[Vector3] = [strike_origin + Vector3(_rng.randf_range(-5.0, 5.0), 48.0, _rng.randf_range(-5.0, 5.0))]
	for index in range(1, 7):
		var t := float(index) / 7.0
		points.append(strike_origin + Vector3(_rng.randf_range(-2.8, 2.8) * (1.0 - t), lerpf(48.0, 0.0, t), _rng.randf_range(-2.8, 2.8) * (1.0 - t)))
	for index in points.size() - 1:
		var start := points[index]
		var finish := points[index + 1]
		var direction := finish - start
		var segment := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.035
		mesh.bottom_radius = 0.055
		mesh.height = direction.length()
		mesh.radial_segments = 5
		mesh.material = material
		segment.mesh = mesh
		bolt.add_child(segment)
		segment.global_position = (start + finish) * 0.5
		segment.global_basis = Basis(Quaternion(Vector3.UP, direction.normalized()))
	await get_tree().create_timer(0.13).timeout
	if is_instance_valid(bolt):
		bolt.queue_free()


func _build_audio() -> void:
	_rain_audio = $WeatherRig/RecordedRain
	_wind_audio = $WeatherRig/RecordedWind
	_thunder_audio = $WeatherRig/SpatialThunder


func _update_audio(delta: float) -> void:
	if _rain_audio == null or _wind_audio == null:
		return
	var local_strength := get_local_intensity()
	var rain_amount := local_strength if state in [State.DRIZZLE, State.STORM] else 0.0
	var wind_amount := clampf(wind.length() / 8.5, 0.0, 1.0)
	var rain_target := lerpf(-28.0, -9.0, rain_amount) if rain_amount > 0.01 else -80.0
	var wind_target := lerpf(-26.0, -12.0, wind_amount) if wind_amount > 0.01 else -80.0
	if rain_amount > 0.01 and not _rain_audio.playing:
		_rain_audio.play()
	_rain_audio.volume_db = move_toward(_rain_audio.volume_db, rain_target, delta * 10.0)
	_wind_audio.volume_db = move_toward(_wind_audio.volume_db, wind_target, delta * 8.0)
	if rain_amount <= 0.01 and _rain_audio.volume_db <= -55.0:
		_rain_audio.stop()
	var wants_strong_wind := (state == State.STORM or state == State.SNOW) and local_strength > 0.6
	var desired_wind := WIND_STRONG if wants_strong_wind else WIND_SOFT
	if _wind_audio.stream != desired_wind:
		_wind_audio.stop()
		_wind_audio.stream = desired_wind
		if desired_wind is AudioStreamOggVorbis:
			(desired_wind as AudioStreamOggVorbis).loop = true
	if wind_amount > 0.01 and not _wind_audio.playing:
		_wind_audio.play()
	elif wind_amount <= 0.01 and _wind_audio.volume_db <= -55.0:
		_wind_audio.stop()


func _schedule_thunder(strike_origin: Vector3, strength: float) -> void:
	if _thunder_audio == null or _player == null:
		return
	var distance := _player.global_position.distance_to(strike_origin)
	var delay := clampf(distance / 343.0, 0.04, 1.4)
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(_thunder_audio):
		return
	_thunder_audio.global_position = strike_origin + Vector3.UP * 14.0
	_thunder_audio.volume_db = lerpf(-10.0, -2.0, strength)
	_thunder_audio.pitch_scale = _rng.randf_range(0.88, 1.04)
	_thunder_audio.play()
