class_name SettingsPanel
extends PanelContainer

signal closed

@onready var visual_intensity_slider: HSlider = %VisualIntensitySlider
@onready var master_volume_slider: HSlider = %MasterVolumeSlider
@onready var head_bob_slider: HSlider = %HeadBobSlider
@onready var fov_slider: HSlider = %FovSlider
@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var resolution_option: OptionButton = %ResolutionOption

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1024, 576),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]


func _ready() -> void:
	_build_display_options()
	visual_intensity_slider.value = float(SettingsService.get_value(&"accessibility", &"visual_intensity", 1.0))
	master_volume_slider.value = float(SettingsService.get_value(&"audio", &"master", 1.0))
	head_bob_slider.value = float(SettingsService.get_value(&"accessibility", &"head_bob", 0.65))
	fov_slider.value = float(SettingsService.get_value(&"video", &"fov", 75.0))
	visual_intensity_slider.value_changed.connect(_on_visual_intensity_changed)
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	head_bob_slider.value_changed.connect(_on_head_bob_changed)
	fov_slider.value_changed.connect(_on_fov_changed)
	window_mode_option.item_selected.connect(_on_window_mode_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	%ResetButton.pressed.connect(_reset_settings)
	%CloseButton.pressed.connect(func() -> void: closed.emit())


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"pause"):
		closed.emit()
		get_viewport().set_input_as_handled()


func focus_first_control() -> void:
	window_mode_option.grab_focus()


func _build_display_options() -> void:
	window_mode_option.clear()
	for entry: Dictionary in [
		{"title": "В окне", "id": &"windowed"},
		{"title": "Без рамки", "id": &"borderless"},
		{"title": "Полный экран", "id": &"fullscreen"},
	]:
		window_mode_option.add_item(entry["title"])
		window_mode_option.set_item_metadata(window_mode_option.item_count - 1, entry["id"])
	resolution_option.clear()
	var saved_resolution := SettingsService.get_resolution()
	var options := RESOLUTIONS.duplicate()
	if saved_resolution not in options:
		options.append(saved_resolution)
	options.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * a.y < b.x * b.y)
	for size: Vector2i in options:
		resolution_option.add_item("%d × %d" % [size.x, size.y])
		resolution_option.set_item_metadata(resolution_option.item_count - 1, size)
	_sync_display_controls()


func _sync_display_controls() -> void:
	var mode := SettingsService.get_window_mode()
	for index: int in window_mode_option.item_count:
		if StringName(window_mode_option.get_item_metadata(index)) == mode:
			window_mode_option.select(index)
			break
	var resolution := SettingsService.get_resolution()
	for index: int in resolution_option.item_count:
		if resolution_option.get_item_metadata(index) == resolution:
			resolution_option.select(index)
			break
	resolution_option.disabled = mode != &"windowed"
	%ResolutionHint.text = "Размер окна применяется сразу" if mode == &"windowed" else "Используется нативный размер текущего экрана"


func _on_window_mode_selected(index: int) -> void:
	SettingsService.set_window_mode(StringName(window_mode_option.get_item_metadata(index)))
	_sync_display_controls()


func _on_resolution_selected(index: int) -> void:
	SettingsService.set_resolution(resolution_option.get_item_metadata(index) as Vector2i)


func _on_visual_intensity_changed(value: float) -> void:
	SettingsService.set_value(&"accessibility", &"visual_intensity", value)


func _on_master_volume_changed(value: float) -> void:
	SettingsService.set_value(&"audio", &"master", value)


func _on_head_bob_changed(value: float) -> void:
	SettingsService.set_value(&"accessibility", &"head_bob", value)


func _on_fov_changed(value: float) -> void:
	SettingsService.set_value(&"video", &"fov", value)


func _reset_settings() -> void:
	SettingsService.reset_to_defaults()
	_build_display_options()
	visual_intensity_slider.set_value_no_signal(float(SettingsService.get_value(&"accessibility", &"visual_intensity", 1.0)))
	master_volume_slider.set_value_no_signal(float(SettingsService.get_value(&"audio", &"master", 1.0)))
	head_bob_slider.set_value_no_signal(float(SettingsService.get_value(&"accessibility", &"head_bob", 0.65)))
	fov_slider.set_value_no_signal(float(SettingsService.get_value(&"video", &"fov", 75.0)))
