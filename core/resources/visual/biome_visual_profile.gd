class_name BiomeVisualProfile
extends Resource

@export var id: StringName
@export var background_color: Color = Color(0.01, 0.02, 0.015)
@export var ambient_color: Color = Color(0.14, 0.18, 0.14)
@export_range(0.0, 4.0, 0.05) var ambient_energy: float = 0.55
@export var fog_color: Color = Color(0.06, 0.1, 0.07)
@export_range(0.0, 0.1, 0.001) var fog_density: float = 0.012
@export_range(0.0, 4.0, 0.05) var fog_light_energy: float = 0.55

