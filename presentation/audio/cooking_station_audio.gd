class_name CookingStationAudio
extends AudioStreamPlayer3D

var _playback: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()
var _state: ThermalVesselState
var _phase: float = 0.0
var _filtered_noise: float = 0.0


func setup(orchestrator: CookingOrchestrator) -> void:
	_state = orchestrator.vessel
	orchestrator.vessel_state_changed.connect(func(state: ThermalVesselState) -> void: _state = state)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_rng.seed = 8127
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.3
	stream = generator
	bus = &"Interactions"
	unit_size = 2.5
	max_distance = 10.0
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	if _playback == null or _state == null:
		return
	var frames := _playback.get_frames_available()
	var mix_rate := (stream as AudioStreamGenerator).mix_rate
	var fire_amount := float(_state.heat_level) * 0.5
	var simmer := clampf(inverse_lerp(55.0, 96.0, _state.temperature), 0.0, 1.0) if _state.water_amount > 0.0 else 0.0
	for _index in frames:
		_phase += 1.0 / mix_rate
		var noise := _rng.randf_range(-1.0, 1.0)
		_filtered_noise = lerpf(_filtered_noise, noise, 0.035)
		var crackle := noise * noise * noise * fire_amount * 0.035
		var bubble_gate := maxf(0.0, sin(_phase * (9.0 + simmer * 13.0) * TAU) - 0.91)
		var bubble := sin(_phase * 145.0 * TAU) * bubble_gate * simmer * 0.12
		var sample := _filtered_noise * fire_amount * 0.025 + crackle + bubble
		_playback.push_frame(Vector2(sample, sample * 0.96))


func _exit_tree() -> void:
	stop()
	_playback = null
