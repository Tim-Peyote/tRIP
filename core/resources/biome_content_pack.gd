class_name BiomeContentPack
extends Resource

enum EcologyFamily {
	ALTAI_TAIGA,
	MYCELIAL_KARST,
	CRIMSON_STEPPE,
	GLACIAL_CIRQUE,
	ASHEN_TUNDRA,
	MIRROR_WETLAND,
	ROOT_CAVERN,
	HEART_PLATEAU,
}

enum VegetationFamily {
	CEDAR_FIR,
	GIANT_FUNGI,
	ANTLER_LARCH,
	ICE_LICHEN,
	BURNT_SNAGS,
	REED_ISLANDS,
	ROOT_COLUMNS,
	CONCORDANT_GROVE,
}

enum GeologyFamily {
	ROUNDED_GRANITE,
	KARST_RIBS,
	RED_SCREE,
	ICE_CRYSTALS,
	ASH_COLUMNS,
	WETLAND_SHELVES,
	ROOT_NODULES,
	FLOATING_STRATA,
}

enum BoundaryFamily {
	MOUNTAIN_RING,
	KARST_WALL,
	RED_ESCARPMENT,
	ICE_CIRQUE,
	ASH_RIDGE,
	MARSH_BLUFF,
	ROOT_RAMPART,
	FRACTURED_PLATEAU,
}

@export var id: StringName
@export var ecology_family: EcologyFamily = EcologyFamily.ALTAI_TAIGA
@export var vegetation_family: VegetationFamily = VegetationFamily.CEDAR_FIR
@export var geology_family: GeologyFamily = GeologyFamily.ROUNDED_GRANITE
@export var poi_family: StringName
@export var composition_family: StringName = &"cedar_windfall"
@export var mystery_ids: Array[StringName] = []
@export var mysteries: Array[WorldMysteryDefinition] = []
@export var local_ingredient_ids: Array[StringName] = []
@export var transition_recipe_id: StringName
@export var next_phase_id: StringName
@export_multiline var landscape_statement: String
@export_range(0.1, 3.0, 0.05) var elevation_scale: float = 1.0
@export_range(0.0, 1.0, 0.05) var ridge_bias: float = 0.25
@export_range(0.0, 1.0, 0.05) var basin_bias: float = 0.0
@export_range(0.0, 1.0, 0.05) var cave_frequency: float = 0.0
@export_range(0.0, 1.0, 0.05) var water_frequency: float = 0.0
@export_range(0.1, 2.5, 0.05) var vegetation_density: float = 1.0
@export_range(0.1, 2.5, 0.05) var geology_density: float = 1.0
@export_range(2, 24, 1) var landmark_period: int = 7
@export_range(1, 8, 1) var composition_period: int = 3
@export_range(0.6, 2.4, 0.05) var composition_scale: float = 1.0
@export_range(0.0, 0.5, 0.01) var ecology_motion_strength: float = 0.08
@export_range(0.1, 3.0, 0.05) var ecology_motion_speed: float = 1.0
@export_category("Art-directed variation")
@export_range(60.0, 280.0, 5.0, "suffix:m") var macro_patch_scale: float = 140.0
@export_range(0.0, 1.0, 0.05) var silhouette_variation: float = 0.35
@export_range(0.0, 0.5, 0.01) var palette_variation: float = 0.16
@export_range(0.0, 1.0, 0.05) var clustering_bias: float = 0.55
@export_range(0.1, 0.8, 0.05) var secondary_variant_bias: float = 0.4
@export_category("Route identity")
@export_range(3.0, 12.0, 0.25, "suffix:m") var route_width: float = 5.5
@export_range(0.25, 2.0, 0.05) var route_wander_scale: float = 1.0
@export_range(0.2, 2.0, 0.05) var route_relief_scale: float = 1.0
@export_range(3, 12, 1, "suffix:chunks") var vista_period_chunks: int = 6
@export_category("Finite region")
@export var boundary_family: BoundaryFamily = BoundaryFamily.MOUNTAIN_RING
@export_range(240.0, 720.0, 10.0, "suffix:m") var region_half_width: float = 410.0
@export_range(540.0, 1200.0, 10.0, "suffix:m") var region_length: float = 920.0
@export_range(-220.0, -40.0, 5.0, "suffix:m") var region_south: float = -120.0
@export_range(0.68, 0.9, 0.01) var boundary_inner_ratio: float = 0.78
@export_range(18.0, 72.0, 1.0, "suffix:m") var boundary_height: float = 48.0
@export_range(0.2, 1.6, 0.05) var highland_bias: float = 0.8
@export_range(0.0, 1.0, 0.05) var lowland_moisture: float = 0.45
@export var ground_low: Color = Color(0.08, 0.16, 0.07)
@export var ground_high: Color = Color(0.3, 0.28, 0.13)
@export var accent_color: Color = Color(0.65, 0.8, 0.35)


func get_generation_signature() -> String:
	return "%s:%d:%d:%d:%s:%s:%.2f:%.2f:%.2f:%d:%d:%.0f:%.0f:%.0f:%.2f:%.2f:%.2f:%.2f" % [id, ecology_family, vegetation_family, geology_family, poi_family, composition_family, route_width, route_wander_scale, route_relief_scale, vista_period_chunks, boundary_family, region_half_width, region_length, macro_patch_scale, silhouette_variation, palette_variation, clustering_bias, secondary_variant_bias]
