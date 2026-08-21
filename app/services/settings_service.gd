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
		"fov": 75.0,
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


func get_value(section: StringName, key: StringName, fallback: Variant = null) -> Variant:
	var section_defaults: Dictionary = DEFAULTS.get(String(section), {})
	var default_value: Variant = section_defaults.get(String(key), fallback)
	return _config.get_value(String(section), String(key), default_value)


func set_value(section: StringName, key: StringName, value: Variant) -> void:
	_config.set_value(String(section), String(key), value)
	_config.save(SETTINGS_PATH)
	_apply_setting(section, key, value)
	setting_changed.emit(section, key, value)


func reset_to_defaults() -> void:
	_config = ConfigFile.new()
	_config.save(SETTINGS_PATH)
	_apply_audio_settings()
	for section: String in DEFAULTS:
		var values: Dictionary = DEFAULTS[section]
		for key: String in values:
			setting_changed.emit(StringName(section), StringName(key), values[key])


func _apply_setting(section: StringName, key: StringName, value: Variant) -> void:
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
