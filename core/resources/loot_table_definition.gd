class_name LootTableDefinition
extends Resource

@export var id: StringName
@export_range(1, 8, 1) var rolls: int = 1
@export var entries: Array[LootEntryDefinition] = []


func generate(seed_value: int) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var optional_entries: Array[LootEntryDefinition] = []
	for entry: LootEntryDefinition in entries:
		if entry.guaranteed:
			var guaranteed_item := entry.create_item(rng)
			if guaranteed_item != null and ContentDB.get_definition(guaranteed_item.definition_id) != null:
				result.append(guaranteed_item)
		else:
			optional_entries.append(entry)
	if optional_entries.is_empty():
		return result
	for roll: int in rolls:
		var entry := optional_entries[(roll + rng.randi_range(0, optional_entries.size() - 1)) % optional_entries.size()]
		var item := entry.create_item(rng)
		if item != null and ContentDB.get_definition(item.definition_id) != null:
			result.append(item)
	return result
