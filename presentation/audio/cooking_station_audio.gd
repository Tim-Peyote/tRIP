class_name CookingStationAudio
extends AudioStreamPlayer3D

const FIRE_LOOP := preload("res://assets/third_party/open_game_art_audio/fire_loop.ogg")
const TOOL_SOFT := preload("res://assets/third_party/kenney_audio/ui/handleSmallLeather.ogg")
const TOOL_WOOD := preload("res://assets/third_party/kenney_audio/ui/bookClose.ogg")
const TOOL_CLICK := preload("res://assets/third_party/kenney_audio/ui/click_003.ogg")
const TOOL_GLASS := preload("res://assets/third_party/kenney_audio/ui/confirmation_002.ogg")
const CROSSFADE_SECONDS: float = 0.42

var _state: ThermalVesselState
var _alternate: AudioStreamPlayer3D
var _active: AudioStreamPlayer3D
var _incoming: AudioStreamPlayer3D
var _crossfade_remaining: float = 0.0
var _action_player: AudioStreamPlayer3D


func setup(orchestrator: CookingOrchestrator) -> void:
	_state = orchestrator.vessel
	orchestrator.vessel_state_changed.connect(func(state: ThermalVesselState) -> void: _state = state)
	orchestrator.physical_action_recorded.connect(_play_action)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_configure_player(self)
	_alternate = AudioStreamPlayer3D.new()
	_alternate.name = "FireLoopCrossfade"
	_configure_player(_alternate)
	add_child(_alternate)
	_action_player = AudioStreamPlayer3D.new()
	_action_player.name = "CookingActionOneShot"
	_action_player.bus = &"Interactions"
	_action_player.unit_size = 1.8
	_action_player.max_distance = 14.0
	_action_player.volume_db = -7.0
	add_child(_action_player)
	_active = self
	# A cold station must be genuinely silent. The old implementation played a
	# loud crackling recording at -32 dB even when HeatLevel was OFF.
	stop()
	_alternate.stop()


func _configure_player(player: AudioStreamPlayer3D) -> void:
	player.stream = FIRE_LOOP
	if player.stream is AudioStreamOggVorbis:
		(player.stream as AudioStreamOggVorbis).loop = false
	player.bus = &"Interactions"
	player.unit_size = 2.2
	player.max_distance = 18.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.volume_db = -80.0


func _process(delta: float) -> void:
	if _state == null or _alternate == null:
		return
	var heat := float(_state.heat_level)
	if heat <= float(ThermalVesselState.HeatLevel.OFF):
		_stop_fire()
		return
	var target_db := lerpf(-17.0, -8.0, clampf(heat / float(ThermalVesselState.HeatLevel.HIGH), 0.0, 1.0))
	var target_pitch := lerpf(0.94, 1.04, clampf(heat / float(ThermalVesselState.HeatLevel.HIGH), 0.0, 1.0))
	if not _active.playing:
		_active.pitch_scale = target_pitch
		_active.volume_db = target_db
		_active.play()
	if _incoming != null:
		_crossfade_remaining = maxf(0.0, _crossfade_remaining - delta)
		var blend := 1.0 - _crossfade_remaining / CROSSFADE_SECONDS
		_active.volume_db = target_db + linear_to_db(maxf(0.001, 1.0 - blend))
		_incoming.volume_db = target_db + linear_to_db(maxf(0.001, blend))
		_active.pitch_scale = target_pitch
		_incoming.pitch_scale = target_pitch
		if _crossfade_remaining <= 0.0:
			_active.stop()
			_active = _incoming
			_incoming = null
		return
	_active.volume_db = target_db
	_active.pitch_scale = target_pitch
	if _active.get_playback_position() >= maxf(0.0, FIRE_LOOP.get_length() - CROSSFADE_SECONDS):
		_incoming = _alternate if _active == self else self
		_incoming.pitch_scale = target_pitch
		_incoming.volume_db = -80.0
		_incoming.play()
		_crossfade_remaining = CROSSFADE_SECONDS


func _stop_fire() -> void:
	if playing:
		stop()
	if _alternate.playing:
		_alternate.stop()
	_active = self
	_incoming = null
	_crossfade_remaining = 0.0


func _play_action(action: StringName) -> void:
	if _action_player == null:
		return
	var cue: AudioStream = TOOL_SOFT
	match action:
		&"hourglass", &"heat_0", &"heat_1", &"heat_2": cue = TOOL_CLICK
		&"transfer", &"stir", &"lower_vessel", &"raise_vessel": cue = TOOL_WOOD
		&"add_water", &"add_kvass", &"add_spirit", &"bottle", &"distill", &"serve": cue = TOOL_GLASS
		&"bellows": cue = TOOL_SOFT
		_: cue = TOOL_SOFT
	if cue is AudioStreamOggVorbis:
		(cue as AudioStreamOggVorbis).loop = false
	_action_player.stop()
	_action_player.stream = cue
	_action_player.pitch_scale = 0.96 + randf() * 0.08
	_action_player.play()
