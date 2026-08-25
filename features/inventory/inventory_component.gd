class_name InventoryComponent
extends Node

signal item_added(item: ItemInstance, display_name: String)
signal item_rejected(definition_id: StringName, reason: String)
signal item_removed(item: ItemInstance)
signal consumable_used(effect_ids: Array[StringName], display_name: String)
signal consumable_consumed(definition_id: StringName, quality: float)
signal changed

@export_range(0.1, 100.0, 0.1) var maximum_volume: float = 8.0
@export_range(0.1, 100.0, 0.1, "suffix:kg") var maximum_mass: float = 12.0

var items: Array[ItemInstance] = []
var _consumption_guard: Callable


func set_consumption_guard(guard: Callable) -> void:
	_consumption_guard = guard


func add_item(item: ItemInstance) -> bool:
	var definition := ContentDB.get_definition(item.definition_id)
	if definition == null:
		item_rejected.emit(item.definition_id, "unknown_definition")
		return false
	var item_mass := _definition_mass(definition) * item.quantity
	var item_volume := _definition_volume(definition) * item.quantity
	if current_mass() + item_mass > maximum_mass:
		item_rejected.emit(item.definition_id, "mass_limit")
		return false
	if current_volume() + item_volume > maximum_volume:
		item_rejected.emit(item.definition_id, "volume_limit")
		return false
	items.append(item)
	item_added.emit(item, definition.display_name)
	changed.emit()
	return true


func count(definition_id: StringName) -> float:
	var result := 0.0
	for item: ItemInstance in items:
		if item.definition_id == definition_id:
			result += item.quantity
	return result


func remove_one(definition_id: StringName) -> ItemInstance:
	for index in items.size():
		var item := items[index]
		if item.definition_id != definition_id:
			continue
		var removed := ItemInstance.from_save_data(item.to_save_data())
		removed.quantity = 1.0
		if item.quantity > 1.0:
			item.quantity -= 1.0
		else:
			items.remove_at(index)
		item_removed.emit(removed)
		changed.emit()
		return removed
	return null


func use_first_consumable() -> bool:
	for index in items.size():
		var item := items[index]
		var definition := ContentDB.get_definition(item.definition_id)
		if not definition is ConsumableDefinition:
			continue
		var consumable := definition as ConsumableDefinition
		return use_consumable(item.definition_id)
	return false


func use_consumable(definition_id: StringName) -> bool:
	var definition := ContentDB.get_definition(definition_id)
	if not definition is ConsumableDefinition:
		return false
	var specimen: ItemInstance
	for item: ItemInstance in items:
		if item.definition_id == definition_id:
			specimen = item
			break
	if specimen == null:
		return false
	if _consumption_guard.is_valid() and not bool(_consumption_guard.call(definition, specimen)):
		item_rejected.emit(definition_id, "metabolic_limit")
		return false
	var removed := remove_one(definition_id)
	if removed == null:
		return false
	var consumable := definition as ConsumableDefinition
	consumable_consumed.emit(definition_id, removed.quality)
	consumable_used.emit(consumable.effect_ids, consumable.display_name)
	return true


func get_stacks() -> Array[Dictionary]:
	var stacks: Dictionary[StringName, Dictionary] = {}
	for item: ItemInstance in items:
		if not stacks.has(item.definition_id):
			stacks[item.definition_id] = {"definition_id": item.definition_id, "quantity": 0.0, "best_quality": 0.0}
		var stack: Dictionary = stacks[item.definition_id]
		stack["quantity"] = float(stack["quantity"]) + item.quantity
		stack["best_quality"] = maxf(float(stack["best_quality"]), item.quality)
		stacks[item.definition_id] = stack
	var result: Array[Dictionary] = []
	result.assign(stacks.values())
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_definition := ContentDB.get_definition(a["definition_id"])
		var b_definition := ContentDB.get_definition(b["definition_id"])
		var a_name := a_definition.display_name if a_definition != null else String(a["definition_id"])
		var b_name := b_definition.display_name if b_definition != null else String(b["definition_id"])
		return a_name.naturalnocasecmp_to(b_name) < 0
	)
	return result


func get_specimens(definition_id: StringName) -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for item: ItemInstance in items:
		if item.definition_id == definition_id:
			result.append(item)
	result.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		if not is_equal_approx(a.quality, b.quality):
			return a.quality > b.quality
		if not is_equal_approx(a.freshness, b.freshness):
			return a.freshness > b.freshness
		return String(a.instance_id) < String(b.instance_id)
	)
	return result


func get_catalog(sort_mode: StringName = &"name") -> Array[Dictionary]:
	var result := get_stacks()
	for entry: Dictionary in result:
		var specimens := get_specimens(entry["definition_id"])
		var freshness_total := 0.0
		var quality_total := 0.0
		var parts: Dictionary[StringName, bool] = {}
		for specimen: ItemInstance in specimens:
			freshness_total += specimen.freshness
			quality_total += specimen.quality
			var part := StringName(specimen.processing_state.get(&"part", &""))
			if part != &"":
				parts[part] = true
		entry["specimen_count"] = specimens.size()
		entry["average_quality"] = quality_total / maxf(1.0, float(specimens.size()))
		entry["average_freshness"] = freshness_total / maxf(1.0, float(specimens.size()))
		entry["parts"] = parts.keys()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		match sort_mode:
			&"quality":
				return float(a["best_quality"]) > float(b["best_quality"])
			&"quantity":
				return float(a["quantity"]) > float(b["quantity"])
			&"freshness":
				return float(a["average_freshness"]) > float(b["average_freshness"])
			_:
				var a_definition := ContentDB.get_definition(a["definition_id"])
				var b_definition := ContentDB.get_definition(b["definition_id"])
				var a_name := a_definition.display_name if a_definition != null else String(a["definition_id"])
				var b_name := b_definition.display_name if b_definition != null else String(b["definition_id"])
				return a_name.naturalnocasecmp_to(b_name) < 0
	)
	return result


func get_display_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for item: ItemInstance in items:
		var definition := ContentDB.get_definition(item.definition_id)
		var label := definition.display_name if definition != null else String(item.definition_id)
		var part := String(item.processing_state.get(&"part", ""))
		var suffix := ""
		if not part.is_empty():
			suffix = " · %s · %d%%" % [part, roundi(item.quality * 100.0)]
		lines.append("%s%s  × %.0f" % [label, suffix, item.quantity])
	return lines


func to_save_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: ItemInstance in items:
		result.append(item.to_save_data())
	return result


func apply_save_data(data: Array) -> void:
	items.clear()
	for raw_item: Variant in data:
		if raw_item is Dictionary:
			var item := ItemInstance.from_save_data(raw_item as Dictionary)
			if ContentDB.get_definition(item.definition_id) != null:
				items.append(item)
	changed.emit()


func current_mass() -> float:
	var result := 0.0
	for item: ItemInstance in items:
		var definition := ContentDB.get_definition(item.definition_id)
		if definition != null:
			result += _definition_mass(definition) * item.quantity
	return result


func current_volume() -> float:
	var result := 0.0
	for item: ItemInstance in items:
		var definition := ContentDB.get_definition(item.definition_id)
		if definition != null:
			result += _definition_volume(definition) * item.quantity
	return result


func _definition_mass(definition: ContentDefinition) -> float:
	if definition is IngredientDefinition:
		return (definition as IngredientDefinition).unit_mass
	if definition is ItemDefinition:
		return (definition as ItemDefinition).mass
	return 0.0


func _definition_volume(definition: ContentDefinition) -> float:
	if definition is IngredientDefinition:
		return (definition as IngredientDefinition).unit_volume
	if definition is ItemDefinition:
		return (definition as ItemDefinition).volume
	return 0.0
