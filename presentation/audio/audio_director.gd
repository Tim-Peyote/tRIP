class_name AudioDirector
extends Node

signal snapshot_changed(snapshot_id: StringName)

const SNAPSHOT_FADE_SECONDS: float = 0.35

var _snapshot_id: StringName = &"default"
var _cue_players: Array[AudioStreamPlayer] = []
var _cue_streams: Dictionary[StringName, AudioStreamWAV] = {}
var _cue_cursor: int = 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for index: int in 4:
		var player := AudioStreamPlayer.new()
		player.name = "UICueVoice_%d" % index
		player.bus = &"UI"
		add_child(player)
		_cue_players.append(player)
	_cue_streams = {
		&"open": _make_cue(0.12, 360.0, 610.0, 0.025, 101),
		&"close": _make_cue(0.1, 520.0, 310.0, 0.018, 102),
		&"select": _make_cue(0.055, 690.0, 760.0, 0.01, 103),
		&"confirm": _make_cue(0.16, 410.0, 820.0, 0.02, 104),
		&"pickup": _make_cue(0.18, 520.0, 940.0, 0.035, 105),
		&"grab": _make_cue(0.09, 170.0, 125.0, 0.12, 106),
		&"release": _make_cue(0.08, 145.0, 230.0, 0.08, 107),
		&"pause": _make_cue(0.14, 280.0, 190.0, 0.03, 108),
	}
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_wire_existing_buttons")


func play_ui_cue(cue_id: StringName) -> void:
	if _cue_players.is_empty() or not _cue_streams.has(cue_id):
		return
	var player := _cue_players[_cue_cursor % _cue_players.size()]
	_cue_cursor += 1
	player.stream = _cue_streams[cue_id]
	player.volume_db = -7.0 if cue_id in [&"select", &"open", &"close"] else -4.0
	player.play()


func _wire_existing_buttons() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"trip_audio_button"):
		_wire_button(node as Button)
	for node: Node in get_tree().root.find_children("*", "Button", true, false):
		_wire_button(node as Button)


func _on_node_added(node: Node) -> void:
	if node is Button:
		call_deferred("_wire_button", node as Button)


func _wire_button(button: Button) -> void:
	if button == null or not is_instance_valid(button) or button.has_meta(&"trip_audio_wired"):
		return
	button.set_meta(&"trip_audio_wired", true)
	button.mouse_entered.connect(play_ui_cue.bind(&"select"))
	button.focus_entered.connect(play_ui_cue.bind(&"select"))
	button.pressed.connect(play_ui_cue.bind(&"confirm"))


func set_snapshot(snapshot_id: StringName) -> void:
	if snapshot_id == _snapshot_id:
		return
	_snapshot_id = snapshot_id
	_apply_snapshot(snapshot_id)
	snapshot_changed.emit(snapshot_id)


func _apply_snapshot(snapshot_id: StringName) -> void:
	var targets: Dictionary = {
		&"default": {&"Music": 0.0, &"Ambience": 0.0, &"Perception": -6.0},
		&"pause": {&"Music": -4.0, &"Ambience": -10.0, &"Perception": -12.0},
		&"danger": {&"Music": -3.0, &"Ambience": -5.0, &"Perception": 0.0},
		&"spore_quiet": {&"Music": -7.0, &"Ambience": -13.0, &"Perception": -18.0},
		&"metamorphosis": {&"Music": -14.0, &"Ambience": -18.0, &"Perception": 3.0},
	}
	var values: Dictionary = targets.get(snapshot_id, targets[&"default"])
	var tween := create_tween().set_parallel(true)
	for bus_name: StringName in values:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			tween.tween_method(
				func(db: float) -> void: AudioServer.set_bus_volume_db(bus_index, db),
				AudioServer.get_bus_volume_db(bus_index),
				float(values[bus_name]),
				SNAPSHOT_FADE_SECONDS
			)


func _make_cue(duration: float, start_frequency: float, end_frequency: float, noise_amount: float, seed_value: int) -> AudioStreamWAV:
	var mix_rate := 22050
	var sample_count := ceili(duration * mix_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var phase := 0.0
	for index: int in sample_count:
		var progress := float(index) / float(maxi(sample_count - 1, 1))
		var frequency := lerpf(start_frequency, end_frequency, progress)
		phase += frequency * TAU / float(mix_rate)
		var attack := smoothstep(0.0, 0.08, progress)
		var release := pow(maxf(1.0 - progress, 0.0), 2.3)
		var tone := sin(phase) * 0.48 + sin(phase * 2.01) * 0.12
		var sample := (tone + rng.randf_range(-1.0, 1.0) * noise_amount) * attack * release
		data.encode_s16(index * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = mix_rate
	result.stereo = false
	result.data = data
	return result
