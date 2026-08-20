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
