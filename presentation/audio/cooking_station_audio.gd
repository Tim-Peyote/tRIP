class_name CookingStationAudio
extends AudioStreamPlayer3D

const FIRE_LOOP := preload("res://assets/third_party/open_game_art_audio/fire_loop.ogg")

var _state: ThermalVesselState


func setup(orchestrator: CookingOrchestrator) -> void:
	_state = orchestrator.vessel
	orchestrator.vessel_state_changed.connect(func(state: ThermalVesselState) -> void: _state = state)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	stream = FIRE_LOOP
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	bus = &"Interactions"
	unit_size = 2.2
	max_distance = 18.0
	attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	volume_db = -24.0
	play()


func _process(_delta: float) -> void:
	if _state == null:
		return
	var heat := float(_state.heat_level)
	volume_db = lerpf(-32.0, -7.0, clampf(heat / 2.0, 0.0, 1.0))
	pitch_scale = lerpf(0.88, 1.08, clampf(heat / 2.0, 0.0, 1.0))
