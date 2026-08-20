class_name CookingProcessEvent
extends RefCounted

var operation: StringName
var ingredient_id: StringName
var ingredient_tags: Array[StringName] = []
var amount: float
var temperature: float
var duration: float
var timestamp: float
var source_quality: float = 1.0
var stir_count: int = -1
var homogeneity: float = -1.0
var overheat_duration: float = -1.0


func _init(
	p_operation: StringName = &"",
	p_ingredient_id: StringName = &"",
	p_amount: float = 0.0,
	p_temperature: float = 20.0,
	p_duration: float = 0.0,
	p_timestamp: float = 0.0
) -> void:
	operation = p_operation
	ingredient_id = p_ingredient_id
	amount = p_amount
	temperature = p_temperature
	duration = p_duration
	timestamp = p_timestamp


func to_save_data() -> Dictionary:
	return {
		"operation": String(operation),
		"ingredient_id": String(ingredient_id),
		"ingredient_tags": ingredient_tags.map(func(value: StringName) -> String: return String(value)),
		"amount": amount,
		"temperature": temperature,
		"duration": duration,
		"timestamp": timestamp,
		"source_quality": source_quality,
		"stir_count": stir_count,
		"homogeneity": homogeneity,
		"overheat_duration": overheat_duration,
	}


static func from_save_data(data: Dictionary) -> CookingProcessEvent:
	var event := CookingProcessEvent.new(
		StringName(data.get("operation", "")),
		StringName(data.get("ingredient_id", "")),
		float(data.get("amount", 0.0)),
		float(data.get("temperature", 20.0)),
		float(data.get("duration", 0.0)),
		float(data.get("timestamp", 0.0))
	)
	for tag: Variant in data.get("ingredient_tags", []):
		event.ingredient_tags.append(StringName(tag))
	event.source_quality = float(data.get("source_quality", 1.0))
	event.stir_count = int(data.get("stir_count", -1))
	event.homogeneity = float(data.get("homogeneity", -1.0))
	event.overheat_duration = float(data.get("overheat_duration", -1.0))
	return event
