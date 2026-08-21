class_name ProceduralAmbience
extends AudioStreamPlayer

@export_range(0.0, 1.0, 0.01) var intensity: float = 0.42
@export var seed: int = 7419

var _playback: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()
var _phase: float = 0.0
var _filtered_noise: float = 0.0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_rng.seed = seed
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = 0.35
	stream = generator
	bus = &"Ambience"
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	var mix_rate := (stream as AudioStreamGenerator).mix_rate
	for _index in frames:
		_phase += TAU / mix_rate
		var raw_noise := _rng.randf_range(-1.0, 1.0)
		_filtered_noise = lerpf(_filtered_noise, raw_noise, 0.0025)
		var low_wind := sin(_phase * 37.0) * 0.014 + sin(_phase * 53.0) * 0.008
		var sample := (_filtered_noise * 0.16 + low_wind) * intensity
		_playback.push_frame(Vector2(sample, sample * 0.97))


func _exit_tree() -> void:
	stop()
	_playback = null
