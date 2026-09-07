class_name LootEntryDefinition
extends Resource

@export var definition_id: StringName
@export var guaranteed: bool = false
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
@export_range(0.01, 20.0, 0.01) var minimum_quantity: float = 1.0
@export_range(0.01, 20.0, 0.01) var maximum_quantity: float = 1.0
@export_range(0.0, 1.0, 0.01) var minimum_quality: float = 0.45
@export_range(0.0, 1.0, 0.01) var maximum_quality: float = 0.9


func create_item(rng: RandomNumberGenerator) -> ItemInstance:
	if definition_id == &"" or (not guaranteed and rng.randf() > chance):
		return null
	var item := ItemInstance.new(definition_id, rng.randf_range(minimum_quantity, maxf(minimum_quantity, maximum_quantity)))
	item.quality = rng.randf_range(minimum_quality, maxf(minimum_quality, maximum_quality))
	item.freshness = rng.randf_range(0.72, 1.0)
	item.processing_state[&"origin"] = &"world_cache"
	return item
