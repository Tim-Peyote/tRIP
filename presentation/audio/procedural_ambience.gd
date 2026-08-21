class_name ProceduralAmbience
extends AudioStreamPlayer

## Historical class name retained for scene compatibility. The implementation now
## uses a recorded forest bed; generated noise caused audible buffer crackle.
const FOREST_AMBIENCE := preload("res://assets/third_party/open_game_art_audio/forest_ambience.mp3")

@export_range(0.0, 1.0, 0.01) var intensity: float = 0.42


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	stream = FOREST_AMBIENCE
	_set_looping(stream)
	bus = &"Ambience"
	# The shelter bed sits behind the expedition and fire layers instead of
	# competing with them when the forest portal is open.
	volume_db = linear_to_db(maxf(0.01, intensity * 0.25))
	play()


func _set_looping(audio_stream: AudioStream) -> void:
	if audio_stream is AudioStreamMP3:
		(audio_stream as AudioStreamMP3).loop = true
	elif audio_stream is AudioStreamOggVorbis:
		(audio_stream as AudioStreamOggVorbis).loop = true
