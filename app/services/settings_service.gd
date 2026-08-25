extends Node

signal setting_changed(section: StringName, key: StringName, value: Variant)

const SETTINGS_PATH: String = "user://settings.cfg"
const DEFAULTS: Dictionary = {
	"audio": {
		"master": 1.0,
		"music": 0.8,
		"ambience": 0.9,
		"effects": 1.0,
		"voice": 1.0,
		"dynamic_range": "normal",
	},
	"video": {
		"fullscreen": false,
		"window_mode": "windowed",
		"resolution_width": 1280,
		"resolution_height": 720,
		"fov": 75.0,
		"graphics_quality": "balanced",
	},
	"accessibility": {
		"visual_intensity": 1.0,
		"camera_shake": 0.65,
		"head_bob": 0.65,
		"chromatic_aberration": 0.55,
		"flashes": true,
		"pause_inventory": false,
	},
}

var _config := ConfigFile.new()


func _ready() -> void:
	_config.load(SETTINGS_PATH)
	_apply_audio_settings()
	_apply_video_settings()


func get_value(section: StringName, key: StringName, fallback: Variant = null) -> Variant:
	var section_defaults: Dictionary = DEFAULTS.get(String(section), {})
	var default_value: Variant = section_defaults.get(String(key), fallback)
	return _config.get_value(String(section), String(key), default_value)


func set_value(section: StringName, key: StringName, value: Variant) -> void:
	_config.set_value(String(section), String(key), value)
	_config.save(SETTINGS_PATH)
	_apply_setting(section, key, value)
	setting_changed.emit(section, key, value)


func set_window_mode(mode: StringName) -> void:
	var normalized := mode if mode in [&"windowed", &"borderless", &"fullscreen"] else &"windowed"
	_config.set_value("video", "window_mode", String(normalized))
	_config.set_value("video", "fullscreen", normalized == &"fullscreen")
	_config.save(SETTINGS_PATH)
	_apply_video_settings()
	setting_changed.emit(&"video", &"window_mode", normalized)


func set_resolution(size: Vector2i) -> void:
	var safe_size := Vector2i(clampi(size.x, 960, 7680), clampi(size.y, 540, 4320))
	_config.set_value("video", "resolution_width", safe_size.x)
	_config.set_value("video", "resolution_height", safe_size.y)
	_config.save(SETTINGS_PATH)
	_apply_video_settings()
	setting_changed.emit(&"video", &"resolution", safe_size)


func get_resolution() -> Vector2i:
	return Vector2i(
		int(get_value(&"video", &"resolution_width", 1280)),
		int(get_value(&"video", &"resolution_height", 720))
	)


func get_window_mode() -> StringName:
	if not _config.has_section_key("video", "window_mode") and bool(get_value(&"video", &"fullscreen", false)):
		return &"fullscreen"
	return StringName(get_value(&"video", &"window_mode", "windowed"))


func reset_to_defaults() -> void:
	_config = ConfigFile.new()
	_config.save(SETTINGS_PATH)
	_apply_audio_settings()
	_apply_video_settings()
	for section: String in DEFAULTS:
		var values: Dictionary = DEFAULTS[section]
		for key: String in values:
			setting_changed.emit(StringName(section), StringName(key), values[key])


func _apply_setting(section: StringName, key: StringName, value: Variant) -> void:
	if section == &"video" and key in [&"window_mode", &"fullscreen", &"resolution_width", &"resolution_height"]:
		_apply_video_settings()
		return
	if section != &"audio":
		return
	var buses_by_key: Dictionary = {
		&"master": [&"Master"],
		&"music": [&"Music"],
		&"ambience": [&"Ambience"],
		&"effects": [&"UI", &"PlayerFoley", &"Creatures", &"Interactions"],
		&"voice": [&"Voice"],
	}
	if not buses_by_key.has(key):
		return
	for bus_name: StringName in buses_by_key[key]:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			AudioServer.set_bus_volume_db(bus_index, linear_to_db(clampf(float(value), 0.0, 1.0)))


func _apply_audio_settings() -> void:
	for key: String in ["master", "music", "ambience", "effects", "voice"]:
		_apply_setting(&"audio", StringName(key), get_value(&"audio", StringName(key)))


func _apply_video_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	if window == null:
		return
	var mode := get_window_mode()
	if mode == &"fullscreen":
		window.borderless = false
		window.mode = Window.MODE_FULLSCREEN
		return
	window.mode = Window.MODE_WINDOWED
	if mode == &"borderless":
		window.borderless = true
		var usable := DisplayServer.screen_get_usable_rect(DisplayServer.SCREEN_OF_MAIN_WINDOW)
		window.position = usable.position
		window.size = usable.size
		return
	window.borderless = false
	var usable_rect := DisplayServer.screen_get_usable_rect(DisplayServer.SCREEN_OF_MAIN_WINDOW)
	var requested := get_resolution()
	var maximum := Vector2i(maxi(960, usable_rect.size.x), maxi(540, usable_rect.size.y))
	window.size = Vector2i(mini(requested.x, maximum.x), mini(requested.y, maximum.y))
	window.position = usable_rect.position + (usable_rect.size - window.size) / 2
