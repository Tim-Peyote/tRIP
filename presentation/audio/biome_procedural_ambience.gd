class_name BiomeProceduralAmbience
extends AudioStreamPlayer

const FOREST := preload("res://assets/third_party/open_game_art_audio/forest_ambience.mp3")
const CREEPY_FOREST := preload("res://assets/third_party/open_game_art_audio/creepy_forest.ogg")
const CAVERN := preload("res://assets/third_party/open_game_art_audio/dark_cavern.ogg")
const DUNGEON := preload("res://assets/third_party/open_game_art_audio/dungeon_ambience.ogg")
const WIND_SOFT := preload("res://assets/third_party/open_game_art_audio/wind_soft.ogg")
const WIND_STRONG := preload("res://assets/third_party/open_game_art_audio/wind_strong.ogg")

var ecology_family: int = 0
var _accent: AudioStreamPlayer


func _ready() -> void:
	bus = &"Ambience"
	_accent = AudioStreamPlayer.new()
	_accent.name = "BiomeAccent"
	_accent.bus = &"Ambience"
	add_child(_accent)


func configure(family: int, seed: int) -> void:
	ecology_family = clampi(family, 0, 7)
	if DisplayServer.get_name() == "headless":
		return
	if _accent == null:
		_ready()
	var beds: Array[AudioStream] = [FOREST, CAVERN, CREEPY_FOREST, WIND_STRONG, WIND_SOFT, DUNGEON, CAVERN, CREEPY_FOREST]
	var accents: Array[AudioStream] = [WIND_SOFT, DUNGEON, WIND_SOFT, CAVERN, CREEPY_FOREST, CAVERN, DUNGEON, WIND_STRONG]
	stream = beds[ecology_family]
	_accent.stream = accents[ecology_family]
	_set_looping(stream)
	_set_looping(_accent.stream)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + ecology_family * 7919
	pitch_scale = rng.randf_range(0.96, 1.025)
	_accent.pitch_scale = rng.randf_range(0.94, 1.035)
	volume_db = [-12.0, -13.5, -13.0, -15.0, -16.0, -12.5, -13.0, -14.0][ecology_family]
	_accent.volume_db = [-24.0, -20.0, -23.0, -21.0, -22.0, -21.0, -19.0, -22.0][ecology_family]
	play(rng.randf_range(0.0, minf(8.0, stream.get_length() * 0.25)))
	_accent.play(rng.randf_range(0.0, minf(5.0, _accent.stream.get_length() * 0.25)))


func _set_looping(audio_stream: AudioStream) -> void:
	if audio_stream is AudioStreamMP3:
		(audio_stream as AudioStreamMP3).loop = true
	elif audio_stream is AudioStreamOggVorbis:
		(audio_stream as AudioStreamOggVorbis).loop = true
