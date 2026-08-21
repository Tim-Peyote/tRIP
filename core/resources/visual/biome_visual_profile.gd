class_name BiomeVisualProfile
extends Resource

@export var id: StringName
@export var background_color: Color = Color(0.01, 0.02, 0.015)
@export var sky_top_color: Color = Color(0.015, 0.055, 0.09)
@export var sky_horizon_color: Color = Color(0.42, 0.22, 0.09)
@export var ground_bottom_color: Color = Color(0.015, 0.022, 0.018)
@export var ground_horizon_color: Color = Color(0.18, 0.12, 0.065)
@export_range(0.0, 8.0, 0.05) var sky_energy: float = 0.8
@export var ambient_color: Color = Color(0.14, 0.18, 0.14)
@export_range(0.0, 4.0, 0.05) var ambient_energy: float = 0.55
@export_range(0.0, 1.0, 0.05) var ambient_sky_contribution: float = 0.35
@export_range(0.25, 3.0, 0.05) var tonemap_exposure: float = 1.1
@export var primary_light_color: Color = Color(0.72, 0.82, 0.68)
@export_range(0.0, 4.0, 0.05) var primary_light_energy: float = 0.85
@export var primary_light_rotation: Vector3 = Vector3(-0.72, -0.48, 0.0)
@export var fog_color: Color = Color(0.06, 0.1, 0.07)
@export_range(0.0, 0.1, 0.001) var fog_density: float = 0.012
@export_range(0.0, 4.0, 0.05) var fog_light_energy: float = 0.55
@export_range(0.0, 0.1, 0.001) var volumetric_density: float = 0.012
@export var volumetric_albedo: Color = Color(0.4, 0.52, 0.42)
@export var volumetric_emission: Color = Color(0.01, 0.025, 0.012)
@export_range(8.0, 128.0, 1.0, "suffix:m") var volumetric_length: float = 48.0
