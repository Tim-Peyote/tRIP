class_name RecipeResolution
extends RefCounted

enum Quality {
	SPOILED,
	UNSTABLE,
	WORKING,
	PURE,
	DISCOVERY,
}

var quality: Quality = Quality.SPOILED
var score: float = 0.0
var result_item_id: StringName
var explanation_tags: Array[StringName] = []
var yield_count: int = 1
var step_scores: Array[float] = []
