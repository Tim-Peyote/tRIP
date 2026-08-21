class_name SettingsPanel
extends PanelContainer

signal closed

@onready var visual_intensity_slider: HSlider = %VisualIntensitySlider
@onready var master_volume_slider: HSlider = %MasterVolumeSlider
@onready var head_bob_slider: HSlider = %HeadBobSlider
@onready var fov_slider: HSlider = %FovSlider


func _ready() -> void:
	visual_intensity_slider.value = float(SettingsService.get_value(&"accessibility", &"visual_intensity", 1.0))
	master_volume_slider.value = float(SettingsService.get_value(&"audio", &"master", 1.0))
	head_bob_slider.value = float(SettingsService.get_value(&"accessibility", &"head_bob", 0.65))
	fov_slider.value = float(SettingsService.get_value(&"video", &"fov", 75.0))
	visual_intensity_slider.value_changed.connect(_on_visual_intensity_changed)
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	head_bob_slider.value_changed.connect(_on_head_bob_changed)
	fov_slider.value_changed.connect(_on_fov_changed)
	%ResetButton.pressed.connect(_reset_settings)
	%CloseButton.pressed.connect(func() -> void: closed.emit())


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"pause"):
		closed.emit()
		get_viewport().set_input_as_handled()


func focus_first_control() -> void:
	visual_intensity_slider.grab_focus()


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
	visual_intensity_slider.set_value_no_signal(float(SettingsService.get_value(&"accessibility", &"visual_intensity", 1.0)))
	master_volume_slider.set_value_no_signal(float(SettingsService.get_value(&"audio", &"master", 1.0)))
	head_bob_slider.set_value_no_signal(float(SettingsService.get_value(&"accessibility", &"head_bob", 0.65)))
	fov_slider.set_value_no_signal(float(SettingsService.get_value(&"video", &"fov", 75.0)))
