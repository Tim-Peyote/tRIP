class_name PlayerFoley
extends Node

var _players: Array[AudioStreamPlayer] = []
var _step_streams: Array[AudioStreamWAV] = []
var _jump_stream: AudioStreamWAV
var _land_stream: AudioStreamWAV
var _cursor: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_rng.seed = 77129
	for index: int in 4:
		var player := AudioStreamPlayer.new()
		player.name = "FoleyVoice_%d" % index
		player.bus = &"PlayerFoley"
		add_child(player)
		_players.append(player)
		_step_streams.append(_make_impact_stream(0.105, 76.0 + index * 7.0, 0.48, 1900 + index * 31))
	_jump_stream = _make_impact_stream(0.14, 118.0, 0.22, 881)
	_land_stream = _make_impact_stream(0.19, 54.0, 0.62, 447)
	var controller := get_parent() as FirstPersonController
	controller.step_taken.connect(_on_step_taken)
	controller.jumped.connect(_on_jumped)
	controller.landed.connect(_on_landed)


func _on_step_taken(_origin: Vector3, intensity: float) -> void:
	_play(_step_streams[_rng.randi_range(0, _step_streams.size() - 1)], lerpf(-13.0, -5.5, intensity), _rng.randf_range(0.93, 1.07))


func _on_jumped() -> void:
	_play(_jump_stream, -11.0, _rng.randf_range(0.97, 1.04))


func _on_landed(impact_speed: float) -> void:
	var strength := clampf(inverse_lerp(2.0, 10.0, impact_speed), 0.0, 1.0)
	_play(_land_stream, lerpf(-13.0, -3.5, strength), lerpf(1.08, 0.88, strength))


func _play(stream_value: AudioStream, volume: float, pitch: float) -> void:
	if _players.is_empty():
		return
	var player := _players[_cursor % _players.size()]
	_cursor += 1
	player.stream = stream_value
	player.volume_db = volume
	player.pitch_scale = pitch
	player.play()


func _make_impact_stream(duration: float, frequency: float, noise_amount: float, seed_value: int) -> AudioStreamWAV:
	var mix_rate := 22050
	var sample_count := ceili(duration * mix_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed_value
	var filtered_noise := 0.0
	for index: int in sample_count:
		var time := float(index) / float(mix_rate)
		var normalized := time / duration
		var envelope := pow(maxf(1.0 - normalized, 0.0), 3.2)
		filtered_noise = lerpf(filtered_noise, local_rng.randf_range(-1.0, 1.0), 0.18)
		var body := sin(time * frequency * TAU) * exp(-time * 28.0)
		var texture := filtered_noise * noise_amount * pow(maxf(1.0 - normalized, 0.0), 2.0)
		var sample := clampf((body * 0.72 + texture) * envelope, -1.0, 1.0)
		data.encode_s16(index * 2, int(sample * 32767.0))
	var stream_value := AudioStreamWAV.new()
	stream_value.format = AudioStreamWAV.FORMAT_16_BITS
	stream_value.mix_rate = mix_rate
	stream_value.stereo = false
	stream_value.data = data
	return stream_value
