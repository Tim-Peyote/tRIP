class_name PlayerFoley
extends Node

var _players: Array[AudioStreamPlayer] = []
var _step_streams: Array[AudioStream] = [
	preload("res://assets/third_party/kenney_audio/foley/footstep_grass_000.ogg"),
	preload("res://assets/third_party/kenney_audio/foley/footstep_grass_001.ogg"),
	preload("res://assets/third_party/kenney_audio/foley/footstep_grass_002.ogg"),
	preload("res://assets/third_party/kenney_audio/foley/footstep_grass_003.ogg"),
	preload("res://assets/third_party/kenney_audio/foley/footstep_grass_004.ogg"),
]
var _jump_stream: AudioStream = preload("res://assets/third_party/kenney_audio/foley/jump_cloth.ogg")
var _land_stream: AudioStream = preload("res://assets/third_party/kenney_audio/foley/land_soft.ogg")
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
