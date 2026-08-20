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
