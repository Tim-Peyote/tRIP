class_name BiomeHazardOrchestrator
extends Node3D

signal state_changed(state: int, title: String, instruction: String)
signal exposure_changed(value: float)
signal overwhelmed(definition: BiomeHazardDefinition, text: String)

enum State { CALM, WARNING, ACTIVE }

const MIN_EXPEDITION_Z := 5.8
const RECORDED_WIND := preload("res://assets/third_party/open_game_art_audio/wind_strong.ogg")
const RECORDED_RAIN := preload("res://assets/third_party/open_game_art_audio/rain_long.ogg")
const RECORDED_CAVERN := preload("res://assets/third_party/open_game_art_audio/dark_cavern.ogg")
const RECORDED_ROOTS := preload("res://assets/third_party/open_game_art_audio/dungeon_ambience.ogg")
const RECORDED_UNCANNY_FOREST := preload("res://assets/third_party/open_game_art_audio/creepy_forest.ogg")

var state: State = State.CALM
var exposure: float = 0.0
var _elapsed: float = 0.0
var _definition: BiomeHazardDefinition
var _player: FirstPersonController
var _terrain: ExpeditionTerrain
var _phases: WorldPhaseOrchestrator
var _laboratory: RoadLaboratoryOrchestrator
var _session_active: bool = false
var _last_safe_position: Vector3
var _particles: GPUParticles3D
var _particle_material: ParticleProcessMaterial
var _draw_material: StandardMaterial3D
var _audio: AudioStreamPlayer3D


func setup(player: FirstPersonController, terrain: ExpeditionTerrain, phases: WorldPhaseOrchestrator, laboratory: RoadLaboratoryOrchestrator = null) -> void:
	_player = player
	_terrain = terrain
	_phases = phases
	_laboratory = laboratory
	_build_presentation()
	phases.phase_changed.connect(_on_phase_changed)
	_on_phase_changed(phases.get_current(), false)
	set_process(true)


func activate_session() -> void:
	_session_active = true
	_last_safe_position = _player.global_position if is_instance_valid(_player) else Vector3.ZERO
	_emit_state()


func get_definition() -> BiomeHazardDefinition:
	return _definition


func force_active() -> bool:
	if _definition == null:
		return false
	state = State.ACTIVE
	_elapsed = 0.0
	_set_presentation_intensity(1.0)
	_emit_state()
	return true


func developer_clear() -> void:
	state = State.CALM
	_elapsed = 0.0
	exposure = 0.0
	if is_instance_valid(_player):
		_last_safe_position = _player.global_position
	_set_presentation_intensity(0.0)
	_emit_state()
	exposure_changed.emit(exposure)


func to_save_data() -> Dictionary:
	return {
		"state": int(state),
		"elapsed": _elapsed,
		"exposure": exposure,
		"last_safe_position": [_last_safe_position.x, _last_safe_position.y, _last_safe_position.z],
	}


func apply_save_data(data: Dictionary) -> void:
	_session_active = true
	state = clampi(int(data.get("state", State.CALM)), State.CALM, State.ACTIVE) as State
	_elapsed = maxf(float(data.get("elapsed", 0.0)), 0.0)
	exposure = clampf(float(data.get("exposure", 0.0)), 0.0, 0.92)
	var position_data := data.get("last_safe_position", []) as Array
	if position_data.size() == 3:
		_last_safe_position = Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
	elif is_instance_valid(_player):
		_last_safe_position = _player.global_position
	_set_presentation_intensity(1.0 if state == State.ACTIVE else 0.35 if state == State.WARNING else 0.0)
	_emit_state()
	exposure_changed.emit(exposure)


func _process(delta: float) -> void:
	if not _session_active or _definition == null or not is_instance_valid(_player):
		return
	global_position = _player.global_position
	var in_expedition := _player.global_position.z >= MIN_EXPEDITION_Z
	if not in_expedition:
		exposure = move_toward(exposure, 0.0, delta * _definition.recovery_rate)
		_set_presentation_intensity(0.0)
		exposure_changed.emit(exposure)
		return
	_elapsed += delta
	if _elapsed >= _state_duration():
		_elapsed = 0.0
		state = wrapi(int(state) + 1, State.CALM, State.ACTIVE + 1) as State
		if state == State.CALM:
			_last_safe_position = _player.global_position
		_set_presentation_intensity(1.0 if state == State.ACTIVE else 0.35 if state == State.WARNING else 0.0)
		_emit_state()
	if state == State.CALM:
		_last_safe_position = _player.global_position
		exposure = move_toward(exposure, 0.0, delta * _definition.recovery_rate)
	elif state == State.WARNING:
		exposure = move_toward(exposure, 0.0, delta * _definition.recovery_rate * 0.4)
	elif _is_countering():
		exposure = move_toward(exposure, 0.0, delta * _definition.recovery_rate)
	else:
		exposure = minf(exposure + delta * _definition.exposure_rate, 1.0)
	exposure_changed.emit(exposure)
	if exposure >= 1.0:
		_overwhelm_player()


func _is_countering() -> bool:
	if _laboratory != null and _laboratory.get_hazard_protection_at(_player.global_position) > 0.5:
		return true
	var speed := _player.get_planar_speed()
	match _definition.counter_rule:
		BiomeHazardDefinition.CounterRule.KEEP_MOVING:
			return speed >= 0.8 and speed <= _player.walk_speed * 1.35
		BiomeHazardDefinition.CounterRule.CROUCH_AND_LISTEN:
			return _player.is_crouched() and speed < 0.7
		BiomeHazardDefinition.CounterRule.WALK_SLOWLY:
			return speed >= 0.18 and speed <= _player.crouch_speed * 1.45
		BiomeHazardDefinition.CounterRule.SEEK_HIGH_GROUND:
			var position := _player.global_position
			var route_x := float(_terrain.call("_route_center_x", position.z))
			var route_height := _terrain.get_height_at_global(Vector3(route_x, 0.0, position.z))
			return position.y >= route_height + 2.25
		_:
			return speed < 0.18


func _overwhelm_player() -> void:
	exposure = 0.34
	_player.global_position = _last_safe_position + Vector3.UP * 0.18
	_player.velocity = Vector3.ZERO
	overwhelmed.emit(_definition, _definition.overwhelmed_text)
	exposure_changed.emit(exposure)


func _on_phase_changed(definition: WorldPhaseDefinition, _developer_override: bool) -> void:
	_definition = definition.hazard_profile if definition != null else null
	state = State.CALM
	_elapsed = 0.0
	exposure = 0.0
	_configure_presentation()
	_emit_state()
	exposure_changed.emit(exposure)


func _state_duration() -> float:
	match state:
		State.WARNING:
			return _definition.warning_duration
		State.ACTIVE:
			return _definition.active_duration
		_:
			return _definition.calm_duration


func _emit_state() -> void:
	if _definition == null:
		state_changed.emit(State.CALM, "", "")
		return
	var title := ""
	var instruction := ""
	if state == State.WARNING:
		title = _definition.warning_text
		instruction = _definition.counter_text
	elif state == State.ACTIVE:
		title = _definition.active_text
		instruction = _definition.counter_text
	state_changed.emit(state, title, instruction)


func _build_presentation() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "BiomeHazardParticles"
	_particles.amount = 220
	_particles.lifetime = 3.8
	_particles.preprocess = 2.0
	_particles.visibility_aabb = AABB(Vector3(-28, -12, -28), Vector3(56, 28, 56))
	_particle_material = ParticleProcessMaterial.new()
	_particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_particle_material.emission_box_extents = Vector3(18, 8, 18)
	_particle_material.spread = 34.0
	_particles.process_material = _particle_material
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.5)
	_draw_material = StandardMaterial3D.new()
	_draw_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_draw_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_draw_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_draw_material.emission_enabled = true
	quad.material = _draw_material
	_particles.draw_pass_1 = quad
	add_child(_particles)
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "BiomeHazardAudio"
	_audio.bus = &"Perception"
	_audio.max_distance = 42.0
	_audio.volume_db = -80.0
	add_child(_audio)


func _configure_presentation() -> void:
	if _definition == null or _particles == null:
		return
	_draw_material.albedo_color = Color(_definition.primary_color, 0.72)
	_draw_material.emission = _definition.primary_color
	_draw_material.emission_energy_multiplier = 1.4
	_particle_material.color = _definition.primary_color
	match _definition.visual_family:
		BiomeHazardDefinition.VisualFamily.WIND, BiomeHazardDefinition.VisualFamily.HUNT:
			_particle_material.direction = Vector3(1.0, 0.15, 0.2)
			_particle_material.initial_velocity_min = 5.0
			_particle_material.initial_velocity_max = 10.0
		BiomeHazardDefinition.VisualFamily.RAIN, BiomeHazardDefinition.VisualFamily.SHARDS:
			_particle_material.direction = Vector3(0.18, -1.0, 0.1)
			_particle_material.initial_velocity_min = 4.0
			_particle_material.initial_velocity_max = 8.0
		BiomeHazardDefinition.VisualFamily.ROOTS, BiomeHazardDefinition.VisualFamily.RESONANCE:
			_particle_material.direction = Vector3(0.0, 1.0, 0.0)
			_particle_material.initial_velocity_min = 0.7
			_particle_material.initial_velocity_max = 2.2
		_:
			_particle_material.direction = Vector3(0.45, -0.25, 0.1)
			_particle_material.initial_velocity_min = 0.8
			_particle_material.initial_velocity_max = 3.0
	_particle_material.gravity = Vector3(0.2, -0.35, 0.05)
	_audio.stream = _get_recorded_hazard_layer(_definition.visual_family)
	if _audio.stream is AudioStreamOggVorbis:
		(_audio.stream as AudioStreamOggVorbis).loop = true
	_audio.pitch_scale = clampf(_definition.audio_pitch, 0.88, 1.12)
	_set_presentation_intensity(0.0)


func _set_presentation_intensity(value: float) -> void:
	if _particles != null:
		_particles.emitting = value > 0.01
		_particles.amount_ratio = clampf(value, 0.0, 1.0)
	if _audio != null:
		_audio.volume_db = lerpf(-80.0, -14.0, clampf(value, 0.0, 1.0))
		if value > 0.01 and not _audio.playing:
			_audio.play()
		elif value <= 0.01:
			_audio.stop()
	RenderingServer.global_shader_parameter_set(&"trip_hazard", clampf(value, 0.0, 1.0))
	if _definition != null:
		RenderingServer.global_shader_parameter_set(&"trip_hazard_color", _definition.primary_color)


func _get_recorded_hazard_layer(family: int) -> AudioStream:
	match family:
		BiomeHazardDefinition.VisualFamily.WIND, BiomeHazardDefinition.VisualFamily.HUNT:
			return RECORDED_WIND
		BiomeHazardDefinition.VisualFamily.RAIN:
			return RECORDED_RAIN
		BiomeHazardDefinition.VisualFamily.ROOTS:
			return RECORDED_ROOTS
		BiomeHazardDefinition.VisualFamily.SHARDS, BiomeHazardDefinition.VisualFamily.RESONANCE:
			return RECORDED_CAVERN
		_:
			return RECORDED_UNCANNY_FOREST
