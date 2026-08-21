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

var state: State = State.CLEAR
var intensity: float = 0.0
var wetness: float = 0.0
var wind: Vector3 = Vector3.ZERO
var automatic: bool = true

var _player: FirstPersonController
var _environment: Environment
var _precipitation: GPUParticles3D
var _lightning: DirectionalLight3D
var _rain_audio: AudioStreamPlayer
var _wind_audio: AudioStreamPlayer
var _thunder_audio: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()
var _state_time: float = 0.0
var _next_change: float = 105.0
var _lightning_time: float = 8.0
var _reactive_tick: float = 0.0
var _base_fog_density: float = 0.012
var _base_volumetric_density: float = 0.012
var _ecology_family: int = BiomeContentPack.EcologyFamily.ALTAI_TAIGA


func setup(world_environment: WorldEnvironment, player: FirstPersonController) -> void:
	_player = player
	_environment = world_environment.environment if world_environment != null else null
	if _environment != null:
		_base_fog_density = _environment.fog_density
		_base_volumetric_density = _environment.volumetric_fog_density
	_rng.seed = 98317
	_build_precipitation()
	_build_lightning()
	_build_audio()
	set_weather(State.CLEAR, 0.0, true)


func _exit_tree() -> void:
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
	return (WEATHER_WEIGHTS.get(_ecology_family, WEATHER_WEIGHTS[BiomeContentPack.EcologyFamily.ALTAI_TAIGA]) as Array).duplicate()


func _process(delta: float) -> void:
	if _player == null:
		return
	global_position = _player.global_position
	_state_time += delta
	_reactive_tick += delta
	_update_surface_state(delta)
	_update_lightning(delta)
	_update_audio(delta)
	if automatic and _state_time >= _next_change:
		_choose_next_weather()
	if _reactive_tick >= 0.5:
		_reactive_tick = 0.0
		_apply_to_reactive_objects()


func set_weather(next_state: State, strength: float = 1.0, immediate: bool = false) -> void:
	state = next_state
	intensity = clampf(strength, 0.0, 1.0)
	_state_time = 0.0
	_next_change = _rng.randf_range(90.0, 170.0)
	_configure_particles()
	_apply_environment(immediate)
	if _player != null:
		_player.set_weather_modifiers(_target_wetness(), wind.length())
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


func get_state_title() -> String:
	return ["Ясно", "Мелкий дождь", "Гроза", "Туман", "Снег"][state]


func get_debug_text() -> String:
	return "%s · сила %d%% · земля %d%% · ветер %.1f м/с · %s" % [
		get_state_title(), roundi(intensity * 100.0), roundi(wetness * 100.0), wind.length(),
		"авто" if automatic else "ручной режим",
	]


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
	match state:
		State.DRIZZLE: return 0.58 * intensity
		State.STORM: return 1.0
		State.FOG: return 0.28 * intensity
		State.SNOW: return 0.38 * intensity
		_: return 0.0


func _update_surface_state(delta: float) -> void:
	var target := _target_wetness()
	var rate := (0.055 + intensity * 0.08) if target > wetness else 0.012
	var next := move_toward(wetness, target, rate * delta)
	if not is_equal_approx(next, wetness):
		wetness = next
		wetness_changed.emit(wetness)
		if _player != null:
			_player.set_weather_modifiers(wetness, wind.length())


func _apply_to_reactive_objects() -> void:
	if get_tree() == null:
		return
	for node: Node in get_tree().get_nodes_in_group(&"weather_reactive"):
		if node is PhysicalPropertyComponent:
			var properties := node as PhysicalPropertyComponent
			if _target_wetness() > 0.0:
				properties.apply_precipitation(0.018 * intensity)
			else:
				properties.dry(0.006)


func _build_precipitation() -> void:
	_precipitation = GPUParticles3D.new()
	_precipitation.name = "LocalPrecipitation"
	_precipitation.amount = 900
	_precipitation.lifetime = 1.5
	_precipitation.visibility_aabb = AABB(Vector3(-18, -14, -18), Vector3(36, 28, 36))
	_precipitation.position = Vector3(0, 9, 0)
	add_child(_precipitation)


func _configure_particles() -> void:
	if _precipitation == null:
		return
	_precipitation.emitting = state in [State.DRIZZLE, State.STORM, State.SNOW] and intensity > 0.02
	_precipitation.amount = roundi(lerpf(280.0, 1500.0, intensity))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(13, 1.5, 13)
	process.direction = Vector3(0.12, -1.0, 0.04) if state != State.SNOW else Vector3(0.08, -0.4, 0.03)
	process.spread = 8.0 if state != State.SNOW else 35.0
	process.gravity = Vector3(0, -10.5, 0) if state != State.SNOW else Vector3(0, -0.8, 0)
	process.initial_velocity_min = 7.0 if state != State.SNOW else 0.6
	process.initial_velocity_max = 12.0 if state != State.SNOW else 1.5
	process.scale_min = 0.55
	process.scale_max = 1.35
	_precipitation.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.018, 0.55) if state != State.SNOW else Vector2(0.065, 0.065)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(0.58, 0.72, 0.78, 0.52) if state != State.SNOW else Color(0.9, 0.95, 1.0, 0.78)
	quad.material = material
	_precipitation.draw_pass_1 = quad
	wind = Vector3(_rng.randf_range(-1.0, 1.0), 0, _rng.randf_range(-0.6, 0.6)).normalized() * lerpf(0.4, 8.5, intensity)
	if state == State.FOG:
		wind *= 0.15


func _apply_environment(immediate: bool) -> void:
	if _environment == null:
		return
	var fog_target := _base_fog_density
	var volumetric_target := _base_volumetric_density
	match state:
		State.FOG:
			fog_target = maxf(fog_target, lerpf(0.025, 0.065, intensity))
			volumetric_target = maxf(volumetric_target, lerpf(0.025, 0.075, intensity))
		State.DRIZZLE:
			fog_target = maxf(fog_target, 0.018 * intensity)
			volumetric_target = maxf(volumetric_target, 0.02 * intensity)
		State.STORM:
			fog_target = maxf(fog_target, 0.027)
			volumetric_target = maxf(volumetric_target, 0.035)
		State.SNOW:
			fog_target = maxf(fog_target, 0.02)
			volumetric_target = maxf(volumetric_target, 0.028)
	if immediate:
		_environment.fog_density = fog_target
		_environment.volumetric_fog_density = volumetric_target
	else:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(_environment, "fog_density", fog_target, 2.8)
		tween.tween_property(_environment, "volumetric_fog_density", volumetric_target, 2.8)


func _build_lightning() -> void:
	_lightning = DirectionalLight3D.new()
	_lightning.name = "LightningFlash"
	_lightning.light_color = Color(0.68, 0.78, 1.0)
	_lightning.light_energy = 0.0
	_lightning.shadow_enabled = false
	_lightning.rotation_degrees = Vector3(-62, -18, 0)
	add_child(_lightning)


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
	_rain_audio = _make_weather_layer("RecordedRain", RAIN_AMBIENCE, -40.0)
	_wind_audio = _make_weather_layer("RecordedWind", WIND_SOFT, -40.0)
	_thunder_audio = AudioStreamPlayer3D.new()
	_thunder_audio.name = "SpatialThunder"
	_thunder_audio.stream = THUNDERCLAP
	if _thunder_audio.stream is AudioStreamWAV:
		(_thunder_audio.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	_thunder_audio.bus = &"Ambience"
	_thunder_audio.unit_size = 12.0
	_thunder_audio.max_distance = 180.0
	_thunder_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_thunder_audio.top_level = true
	add_child(_thunder_audio)


func _make_weather_layer(layer_name: String, audio_stream: AudioStream, initial_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = layer_name
	player.bus = &"Ambience"
	player.stream = audio_stream
	if audio_stream is AudioStreamOggVorbis:
		(audio_stream as AudioStreamOggVorbis).loop = true
	elif audio_stream is AudioStreamMP3:
		(audio_stream as AudioStreamMP3).loop = true
	player.volume_db = initial_db
	add_child(player)
	return player


func _update_audio(delta: float) -> void:
	if _rain_audio == null or _wind_audio == null:
		return
	var rain_amount := intensity if state in [State.DRIZZLE, State.STORM] else 0.0
	var wind_amount := clampf(wind.length() / 8.5, 0.0, 1.0)
	var rain_target := lerpf(-28.0, -9.0, rain_amount) if rain_amount > 0.01 else -80.0
	var wind_target := lerpf(-26.0, -12.0, wind_amount) if wind_amount > 0.01 else -80.0
	if rain_amount > 0.01 and not _rain_audio.playing:
		_rain_audio.play()
	_rain_audio.volume_db = move_toward(_rain_audio.volume_db, rain_target, delta * 10.0)
	_wind_audio.volume_db = move_toward(_wind_audio.volume_db, wind_target, delta * 8.0)
	if rain_amount <= 0.01 and _rain_audio.volume_db <= -55.0:
		_rain_audio.stop()
	var wants_strong_wind := (state == State.STORM or state == State.SNOW) and intensity > 0.6
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
