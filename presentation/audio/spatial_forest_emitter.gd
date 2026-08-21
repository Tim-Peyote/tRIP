class_name SpatialForestEmitter
extends AudioStreamPlayer3D

const WIND_GUST := preload("res://assets/third_party/open_game_art_audio/wind_gust.ogg")
const CAVERN := preload("res://assets/third_party/open_game_art_audio/dark_cavern.ogg")
const CREEPY_FOREST := preload("res://assets/third_party/open_game_art_audio/creepy_forest.ogg")

@export_enum("whisper", "drip", "pulse") var voice: String = "whisper"
@export_range(0.0, 1.0, 0.01) var intensity: float = 0.2
@export var seed: int = 1701
@export var start_active: bool = false

var _configured := false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	stream = {"whisper": WIND_GUST, "drip": CAVERN, "pulse": CREEPY_FOREST}.get(voice, WIND_GUST)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	bus = &"Ambience"
	unit_size = 2.8
	max_distance = 24.0
	attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	volume_db = linear_to_db(maxf(0.01, intensity * 0.32))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	pitch_scale = rng.randf_range(0.92, 1.06)
	_configured = true
	if start_active:
		play(rng.randf_range(0.0, minf(4.0, stream.get_length() * 0.2)))


func set_audio_active(value: bool) -> void:
	start_active = value
	if not _configured:
		return
	if value:
		if not playing:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed + Time.get_ticks_msec()
			play(rng.randf_range(0.0, minf(4.0, stream.get_length() * 0.2)))
	elif playing:
		stop()


func is_audio_active() -> bool:
	return start_active and playing
