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
var _expedition_active: bool = false
var _bed_volume_db: float = -80.0
var _accent_volume_db: float = -80.0


func _ready() -> void:
	bus = &"Ambience"
	_accent = AudioStreamPlayer.new()
	_accent.name = "BiomeAccent"
	_accent.bus = &"Ambience"
	add_child(_accent)


func configure(family: int, seed: int) -> void:
	ecology_family = clampi(family, 0, 7)
	if _accent == null:
		_accent = AudioStreamPlayer.new()
		_accent.name = "BiomeAccent"
		_accent.bus = &"Ambience"
		add_child(_accent)
	# A biome owns exactly these two voices. Stop both before replacing their
	# streams so no previous ecology survives the consciousness transition.
	stop()
	_accent.stop()
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
	# Source-aware gain matching: the forest recording is nearly 40 dB quieter
	# than the cavern recording, so a single attenuation table made it inaudible.
	_bed_volume_db = [14.0, -18.0, -8.0, 0.0, -2.0, -4.0, -18.0, -8.0][ecology_family]
	_accent_volume_db = [-6.0, -14.0, -8.0, -26.0, -16.0, -26.0, -12.0, -8.0][ecology_family]
	volume_db = _bed_volume_db
	_accent.volume_db = _accent_volume_db
	if _expedition_active and DisplayServer.get_name() != "headless":
		_start_layers(rng)


func set_expedition_active(value: bool) -> void:
	if _expedition_active == value:
		return
	_expedition_active = value
	if not _expedition_active:
		stop()
		if _accent != null:
			_accent.stop()
		return
	if stream == null or _accent == null or _accent.stream == null or DisplayServer.get_name() == "headless":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = ecology_family * 7919 + 31
	_start_layers(rng)


func _start_layers(rng: RandomNumberGenerator) -> void:
	volume_db = _bed_volume_db
	_accent.volume_db = _accent_volume_db
	play(rng.randf_range(0.0, minf(8.0, stream.get_length() * 0.25)))
	_accent.play(rng.randf_range(0.0, minf(5.0, _accent.stream.get_length() * 0.25)))


func get_bed_stream_path() -> String:
	return stream.resource_path if stream != null else ""


func get_accent_stream_path() -> String:
	return _accent.stream.resource_path if _accent != null and _accent.stream != null else ""


func is_expedition_active() -> bool:
	return _expedition_active


func _set_looping(audio_stream: AudioStream) -> void:
	if audio_stream is AudioStreamMP3:
		(audio_stream as AudioStreamMP3).loop = true
	elif audio_stream is AudioStreamOggVorbis:
		(audio_stream as AudioStreamOggVorbis).loop = true
