class_name InventoryComponent
extends Node

signal item_added(item: ItemInstance, display_name: String)
signal item_rejected(definition_id: StringName, reason: String)
signal item_removed(item: ItemInstance)
signal consumable_used(effect_ids: Array[StringName], display_name: String)
signal changed

@export_range(0.1, 100.0, 0.1) var maximum_volume: float = 8.0
@export_range(0.1, 100.0, 0.1, "suffix:kg") var maximum_mass: float = 12.0

var items: Array[ItemInstance] = []


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
		items.remove_at(index)
		item_removed.emit(item)
		changed.emit()
		return item
	return null


func use_first_consumable() -> bool:
	for index in items.size():
		var item := items[index]
		var definition := ContentDB.get_definition(item.definition_id)
		if not definition is ConsumableDefinition:
			continue
		var consumable := definition as ConsumableDefinition
		items.remove_at(index)
		item_removed.emit(item)
		changed.emit()
		consumable_used.emit(consumable.effect_ids, consumable.display_name)
		return true
	return false


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
