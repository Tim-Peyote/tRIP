class_name SpatialForestEmitter
extends AudioStreamPlayer3D

@export_enum("whisper", "drip", "pulse") var voice: String = "whisper"
@export_range(0.0, 1.0, 0.01) var intensity: float = 0.2
@export var seed: int = 1701

var _playback: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()
var _time: float = 0.0
var _filtered_noise: float = 0.0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_rng.seed = seed
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.3
	stream = generator
	bus = &"Ambience"
	unit_size = 3.0
	max_distance = 18.0
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	var mix_rate := (stream as AudioStreamGenerator).mix_rate
	for _index in frames:
		_time += 1.0 / mix_rate
		var noise := _rng.randf_range(-1.0, 1.0)
		_filtered_noise = lerpf(_filtered_noise, noise, 0.003)
		var sample := 0.0
		match voice:
			"drip":
				var gate := maxf(0.0, sin(_time * 0.47 * TAU) - 0.992)
				sample = sin(_time * 620.0 * TAU) * gate * 0.22
			"pulse":
				var pulse := pow(maxf(0.0, sin(_time * 0.31 * TAU)), 10.0)
				sample = sin(_time * 46.0 * TAU) * pulse * 0.06 + _filtered_noise * 0.025
			_:
				sample = _filtered_noise * 0.12 + sin(_time * 71.0 * TAU) * 0.006
		sample *= intensity
		_playback.push_frame(Vector2(sample, sample * 0.94))


func _exit_tree() -> void:
	stop()
	_playback = null

