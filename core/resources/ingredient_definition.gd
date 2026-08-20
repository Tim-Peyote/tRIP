class_name IngredientDefinition
extends ContentDefinition

enum HarvestPart {
	WHOLE,
	CAP,
	STEM,
	ROOT,
	LEAF,
	BERRY,
	SPORES,
}

@export_category("Field")
@export var harvest_parts: Array[HarvestPart] = [HarvestPart.WHOLE]
@export_range(0.01, 20.0, 0.01, "suffix:kg") var unit_mass: float = 0.1
@export_range(0.01, 20.0, 0.01) var unit_volume: float = 0.1
@export_range(0.0, 168.0, 0.5, "suffix:h") var freshness_hours: float = 24.0
@export var biome_tags: Array[StringName] = []

@export_category("Processing")
@export var allowed_operations: Array[StringName] = []
@export var trait_channels: Dictionary[StringName, float] = {}

@export_category("Presentation")
@export var world_scene: PackedScene
@export var inventory_icon: Texture2D
@export var inspect_scene: PackedScene
@export var inspection_clues: Array[InspectionClueDefinition] = []


func validate() -> PackedStringArray:
	var messages := super()
	if unit_mass <= 0.0:
		messages.append("Ingredient '%s' must have positive mass." % id)
	if unit_volume <= 0.0:
		messages.append("Ingredient '%s' must have positive volume." % id)
	if harvest_parts.is_empty():
		messages.append("Ingredient '%s' has no harvestable parts." % id)
	for index in inspection_clues.size():
		if inspection_clues[index] == null:
			messages.append("Ingredient '%s' inspection clue %d is null." % [id, index])
		else:
			messages.append_array(inspection_clues[index].validate(index))
	return messages
