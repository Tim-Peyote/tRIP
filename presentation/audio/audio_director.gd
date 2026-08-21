class_name AudioDirector
extends Node

signal snapshot_changed(snapshot_id: StringName)

const SNAPSHOT_FADE_SECONDS: float = 0.35
const STABLE_AUDIO_BUS_STATE: Dictionary[StringName, bool] = {
	&"Music": true,
	&"UI": true,
	&"PlayerFoley": false,
	&"World": false,
	&"Ambience": false,
	&"Creatures": true,
	&"Interactions": true,
	&"Voice": true,
	&"Perception": true,
}

var _snapshot_id: StringName = &"default"
var _cue_players: Array[AudioStreamPlayer] = []
var _cue_streams: Dictionary[StringName, AudioStream] = {
	&"open": preload("res://assets/third_party/kenney_audio/ui/handleSmallLeather.ogg"),
	&"close": preload("res://assets/third_party/kenney_audio/ui/dropLeather.ogg"),
	&"select": preload("res://assets/third_party/kenney_audio/ui/handleSmallLeather.ogg"),
	&"confirm": preload("res://assets/third_party/kenney_audio/ui/bookClose.ogg"),
	&"pickup": preload("res://assets/third_party/kenney_audio/ui/handleSmallLeather.ogg"),
	&"grab": preload("res://assets/third_party/kenney_audio/ui/handleSmallLeather.ogg"),
	&"release": preload("res://assets/third_party/kenney_audio/ui/dropLeather.ogg"),
	&"pause": preload("res://assets/third_party/kenney_audio/ui/bookClose.ogg"),
}
var _cue_cursor: int = 0


func _ready() -> void:
	_apply_stable_audio_bus_state()
	var master_bus := AudioServer.get_bus_index(&"Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, false)
	if DisplayServer.get_name() == "headless":
		return
	for index: int in 4:
		var player := AudioStreamPlayer.new()
		player.name = "UICueVoice_%d" % index
		player.bus = &"UI"
		add_child(player)
		_cue_players.append(player)
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_wire_existing_buttons")


func _apply_stable_audio_bus_state() -> void:
	for bus_name: StringName in STABLE_AUDIO_BUS_STATE:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			AudioServer.set_bus_mute(bus_index, STABLE_AUDIO_BUS_STATE[bus_name])


func is_stable_audio_bus_state_applied() -> bool:
	for bus_name: StringName in STABLE_AUDIO_BUS_STATE:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index < 0 or AudioServer.is_bus_mute(bus_index) != STABLE_AUDIO_BUS_STATE[bus_name]:
			return false
	return true


func is_master_audio_enabled() -> bool:
	var master_bus := AudioServer.get_bus_index(&"Master")
	return master_bus >= 0 and not AudioServer.is_bus_mute(master_bus)


func play_ui_cue(cue_id: StringName) -> void:
	if _cue_players.is_empty() or not _cue_streams.has(cue_id):
		return
	var player := _cue_players[_cue_cursor % _cue_players.size()]
	_cue_cursor += 1
	player.stream = _cue_streams[cue_id]
	player.volume_db = -18.0 if cue_id == &"select" else -10.0 if cue_id in [&"open", &"close"] else -7.0
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
