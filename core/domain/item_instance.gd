class_name ItemInstance
extends RefCounted

var instance_id: StringName
var definition_id: StringName
var quantity: float = 1.0
var quality: float = 1.0
var freshness: float = 1.0
var processing_state: Dictionary[StringName, Variant] = {}


func _init(p_definition_id: StringName = &"", p_quantity: float = 1.0) -> void:
	instance_id = StringName("item_%s" % ResourceUID.create_id())
	definition_id = p_definition_id
	quantity = maxf(0.0, p_quantity)


func to_save_data() -> Dictionary:
	return {
		"instance_id": String(instance_id),
		"definition_id": String(definition_id),
		"quantity": quantity,
		"quality": quality,
		"freshness": freshness,
		"processing_state": processing_state,
	}


static func from_save_data(data: Dictionary) -> ItemInstance:
	var item := ItemInstance.new(StringName(data.get("definition_id", "")), float(data.get("quantity", 1.0)))
	item.instance_id = StringName(data.get("instance_id", String(item.instance_id)))
	item.quality = clampf(float(data.get("quality", 1.0)), 0.0, 1.0)
	item.freshness = clampf(float(data.get("freshness", 1.0)), 0.0, 1.0)
	var saved_state: Dictionary = data.get("processing_state", {}) as Dictionary
	item.processing_state.clear()
	for key: Variant in saved_state:
		item.processing_state[StringName(key)] = saved_state[key]
	return item
