class_name WorldMetamorphosisDirector
extends Node

signal transition_started(definition: WorldPhaseDefinition, duration: float)
signal transition_peaked(definition: WorldPhaseDefinition)
signal transition_finished(definition: WorldPhaseDefinition)

const ONSET_SECONDS: float = 0.82
const SETTLE_SECONDS: float = 1.95

var _orchestrator: WorldPhaseOrchestrator
var _target_definition: WorldPhaseDefinition
var _last_phase_id: StringName
var _transition_tween: Tween
var _transition_progress: float = 0.0
var _audio_player: AudioStreamPlayer


func _ready() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = &"Perception"
	_audio_player.stream = _build_transition_sound()
	add_child(_audio_player)
	_set_transition_progress(0.0)


func _exit_tree() -> void:
	clear()
	if _audio_player != null:
		_audio_player.stream = null


func setup(orchestrator: WorldPhaseOrchestrator) -> void:
	if _orchestrator != null and _orchestrator.phase_changed.is_connected(_on_phase_changed):
		_orchestrator.phase_changed.disconnect(_on_phase_changed)
	_orchestrator = orchestrator
	if _orchestrator == null:
		return
	_orchestrator.phase_changed.connect(_on_phase_changed)
	var current := _orchestrator.get_current()
	_last_phase_id = current.id if current != null else &""


func clear() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
	_target_definition = null
	_last_phase_id = &""
	_set_transition_progress(0.0)
	if _audio_player != null:
		_audio_player.stop()


func is_transitioning() -> bool:
	return _target_definition != null


func get_target_phase_id() -> StringName:
	return _target_definition.id if _target_definition != null else &""


func get_transition_progress() -> float:
	return _transition_progress


func finish_immediately() -> void:
	if _target_definition == null:
		return
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_set_transition_progress(0.0)
	_finish_transition()


func _on_phase_changed(definition: WorldPhaseDefinition, _developer_override: bool) -> void:
	if definition == null or definition.id == _last_phase_id:
		return
	_last_phase_id = definition.id
	_begin_transition(definition)


func _begin_transition(definition: WorldPhaseDefinition) -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_target_definition = definition
	RenderingServer.global_shader_parameter_set(&"trip_world_color", definition.beacon_color)
	RenderingServer.global_shader_parameter_set(&"trip_world_family", float(definition.geometry_family))
	_set_transition_progress(0.0)
	if _audio_player != null:
		_audio_player.play()
	transition_started.emit(definition, ONSET_SECONDS + SETTLE_SECONDS)
	_transition_tween = create_tween()
	_transition_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_transition_tween.tween_method(_set_transition_progress, 0.0, 1.0, ONSET_SECONDS)
	_transition_tween.tween_callback(func() -> void: transition_peaked.emit(definition))
	_transition_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_method(_set_transition_progress, 1.0, 0.0, SETTLE_SECONDS)
	_transition_tween.tween_callback(_finish_transition)


func _set_transition_progress(value: float) -> void:
	_transition_progress = clampf(value, 0.0, 1.0)
	RenderingServer.global_shader_parameter_set(&"trip_world_transition", _transition_progress)


func _finish_transition() -> void:
	var finished_definition := _target_definition
	_target_definition = null
	_transition_tween = null
	if finished_definition != null:
		transition_finished.emit(finished_definition)


func _build_transition_sound() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := ONSET_SECONDS + SETTLE_SECONDS
	var sample_count := int(duration * sample_rate)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in sample_count:
		var time := float(index) / float(sample_rate)
		var normalized := time / duration
		var envelope := sin(PI * clampf(normalized, 0.0, 1.0))
		var rising_tone := lerpf(38.0, 112.0, smoothstep(0.0, 1.0, normalized))
		var drone := sin(TAU * rising_tone * time) * 0.34
		var beating := sin(TAU * (rising_tone * 1.013) * time) * 0.22
		var overtone := sin(TAU * (184.0 + sin(time * 2.1) * 24.0) * time) * 0.1
		var sample := clampf((drone + beating + overtone) * envelope, -0.85, 0.85)
		bytes.encode_s16(index * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream
