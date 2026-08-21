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
@export var ground_low: Color = Color(0.08, 0.16, 0.07)
@export var ground_high: Color = Color(0.3, 0.28, 0.13)
@export var accent_color: Color = Color(0.65, 0.8, 0.35)


func get_generation_signature() -> String:
	return "%s:%d:%d:%d:%s:%s" % [id, ecology_family, vegetation_family, geology_family, poi_family, composition_family]
