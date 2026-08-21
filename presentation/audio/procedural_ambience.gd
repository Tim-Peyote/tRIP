class_name ProceduralAmbience
extends AudioStreamPlayer

## Historical class name retained for scene compatibility. The implementation now
## uses a recorded forest bed; generated noise caused audible buffer crackle.
const FOREST_AMBIENCE := preload("res://assets/third_party/open_game_art_audio/forest_ambience.mp3")

@export_range(0.0, 1.0, 0.01) var intensity: float = 0.42
@export var expedition_boundary_z: float = 5.8

var _listener: Node3D
var _shelter_active: bool = true
var _shelter_volume_db: float = 0.0
var _ambience_enabled: bool = true


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	stream = FOREST_AMBIENCE
	_set_looping(stream)
	bus = &"Ambience"
	# The shelter bed sits behind the expedition and fire layers instead of
	# competing with them when the forest portal is open.
	# This field recording is mastered very quietly (about -53 dB RMS).
	_shelter_volume_db = 10.0 + linear_to_db(maxf(0.01, intensity))
	volume_db = _shelter_volume_db
	play()
	set_process(true)


func setup(listener: Node3D) -> void:
	_listener = listener
	_update_zone_state()


func _process(_delta: float) -> void:
	_update_zone_state()


func _update_zone_state() -> void:
	if not _ambience_enabled:
		if playing:
			stop()
		_shelter_active = false
		return
	if not is_instance_valid(_listener):
		return
	var should_be_active := _listener.global_position.z < expedition_boundary_z
	if should_be_active == _shelter_active:
		return
	_shelter_active = should_be_active
	if _shelter_active:
		volume_db = _shelter_volume_db
		if not playing and DisplayServer.get_name() != "headless":
			play()
	else:
		stop()


func is_shelter_active() -> bool:
	return _shelter_active


func set_ambience_enabled(value: bool) -> void:
	_ambience_enabled = value
	_update_zone_state()


func _set_looping(audio_stream: AudioStream) -> void:
	if audio_stream is AudioStreamMP3:
		(audio_stream as AudioStreamMP3).loop = true
	elif audio_stream is AudioStreamOggVorbis:
		(audio_stream as AudioStreamOggVorbis).loop = true
