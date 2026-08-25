class_name ConsumableDefinition
extends ItemDefinition

@export var effect_ids: Array[StringName] = []
@export_range(1, 16, 1) var doses: int = 1

@export_category("Body and Nutrition")
@export var occupies_food_slot: bool = true
@export var nutrition_group: StringName = &"meal"
@export_range(1.0, 3600.0, 1.0, "suffix:s") var nutrition_duration_seconds: float = 600.0
@export_range(0.0, 200.0, 1.0) var maximum_health_bonus: float = 0.0
@export_range(0.0, 200.0, 1.0) var maximum_stamina_bonus: float = 0.0
@export_range(0.0, 10.0, 0.05, "suffix:/s") var health_regeneration: float = 0.0
@export_range(-1.0, 1.0, 0.01) var warmth_bonus: float = 0.0
@export_range(-1.0, 1.0, 0.01) var cold_resistance_bonus: float = 0.0
@export_range(-1.0, 1.0, 0.01) var spore_resistance_bonus: float = 0.0
@export_range(0.0, 1.0, 0.01) var toxicity: float = 0.0


func validate() -> PackedStringArray:
	var messages := super()
	if effect_ids.is_empty():
		messages.append("Consumable '%s' has no effects." % id)
	if occupies_food_slot and nutrition_group == &"":
		messages.append("Consumable '%s' occupies a food slot but has no nutrition group." % id)
	return messages
