class_name BiomeProceduralAmbience
extends AudioStreamPlayer

var ecology_family: int = 0
var _playback: AudioStreamGeneratorPlayback
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _noise := 0.0


func configure(family: int, seed: int) -> void:
	ecology_family = family
	_rng.seed = seed + family * 7919
	_time = 0.0
	if DisplayServer.get_name() == "headless":
		return
	if stream == null:
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
	var rate := (stream as AudioStreamGenerator).mix_rate
	for _index in frames:
		_time += 1.0 / rate
		_noise = lerpf(_noise, _rng.randf_range(-1.0, 1.0), 0.0018)
		var fundamental: float = float([37.0, 43.0, 56.0, 83.0, 29.0, 67.0, 34.0, 48.0][ecology_family])
		var tone := sin(_time * fundamental * TAU)
		var overtone := sin(_time * fundamental * (1.5 + float(ecology_family % 3) * 0.25) * TAU)
		var pulse := pow(maxf(0.0, sin(_time * (0.12 + ecology_family * 0.025) * TAU)), 6.0)
		var noise_amount: float = float([0.1, 0.055, 0.14, 0.035, 0.18, 0.07, 0.045, 0.035][ecology_family])
		var tonal_amount: float = float([0.008, 0.022, 0.012, 0.026, 0.006, 0.018, 0.025, 0.032][ecology_family])
		var sample: float = _noise * noise_amount + (tone * 0.7 + overtone * 0.3) * tonal_amount * (0.35 + pulse)
		sample *= 0.22
		_playback.push_frame(Vector2(sample, sample * (0.92 + 0.01 * ecology_family)))


func _exit_tree() -> void:
	stop()
	_playback = null
