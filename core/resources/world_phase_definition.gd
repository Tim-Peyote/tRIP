class_name WorldPhaseDefinition
extends Resource

@export var id: StringName
@export var order: int = 0
@export var display_name: String
@export_multiline var description: String
@export var effect_channel: StringName
@export var stabilizing_recipe_id: StringName
@export var visual_profile: BiomeVisualProfile
@export var content_pack: BiomeContentPack
@export_range(0, 4, 1) var geometry_family: int = 0
@export var canopy_low: Color = Color(0.05, 0.2, 0.07)
@export var canopy_high: Color = Color(0.35, 0.5, 0.1)
@export var stone_low: Color = Color(0.18, 0.22, 0.2)
@export var stone_high: Color = Color(0.46, 0.4, 0.28)
@export var beacon_color: Color = Color(0.7, 0.12, 0.6)
@export var poi_family: StringName = &"forest_trace"
@export var cave_bias: float = 0.0
@export var hazard_bias: float = 0.0


func is_baseline() -> bool:
	return order == 0 or effect_channel == &""
