class_name SettingsPanel
extends PanelContainer

signal closed

@onready var visual_intensity_slider: HSlider = %VisualIntensitySlider
@onready var master_volume_slider: HSlider = %MasterVolumeSlider


func _ready() -> void:
	visual_intensity_slider.value = float(SettingsService.get_value(&"accessibility", &"visual_intensity", 1.0))
	master_volume_slider.value = float(SettingsService.get_value(&"audio", &"master", 1.0))
	visual_intensity_slider.value_changed.connect(_on_visual_intensity_changed)
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	%CloseButton.pressed.connect(func() -> void: closed.emit())


func focus_first_control() -> void:
	visual_intensity_slider.grab_focus()


func _on_visual_intensity_changed(value: float) -> void:
	SettingsService.set_value(&"accessibility", &"visual_intensity", value)


func _on_master_volume_changed(value: float) -> void:
	SettingsService.set_value(&"audio", &"master", value)

