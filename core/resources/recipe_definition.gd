class_name RecipeDefinition
extends ContentDefinition

enum FinishMethod { BOTTLE, DISTILL, SERVE }

@export var primary_ingredient_id: StringName
@export var steps: Array[RecipeStepDefinition] = []
@export var result_item_id: StringName
@export var effect_ids: Array[StringName] = []
@export var required_base_id: StringName = &"base.water"
@export var finish_method: FinishMethod = FinishMethod.BOTTLE
@export_range(0, 3, 1) var minimum_station_tier: int = 0
@export_range(1, 6, 1) var base_yield: int = 1
@export_range(0.0, 1.0, 0.01) var acceptable_error: float = 0.25
@export_multiline var field_notes: String


func validate() -> PackedStringArray:
	var messages := super()
	if steps.is_empty():
		messages.append("Recipe '%s' has no steps." % id)
	if primary_ingredient_id == &"":
		messages.append("Recipe '%s' has no primary ingredient id." % id)
	for index in steps.size():
		if steps[index] == null:
			messages.append("Recipe '%s' step %d is null." % [id, index])
		else:
			messages.append_array(steps[index].validate(index))
	if result_item_id == &"":
		messages.append("Recipe '%s' has no result item id." % id)
	if required_base_id == &"":
		messages.append("Recipe '%s' has no liquid base." % id)
	return messages
