class_name RecipeResolver
extends RefCounted


func resolve(process: CookingProcess, recipe: RecipeDefinition) -> RecipeResolution:
	var result := RecipeResolution.new()
	result.result_item_id = recipe.result_item_id
	if recipe.steps.is_empty() or process.events.is_empty():
		result.explanation_tags.append(&"incomplete_process")
		return result

	var matches := 0.0
	var source_quality := 1.0
	var compared_steps := mini(process.events.size(), recipe.steps.size())
	for index in compared_steps:
		var event := process.events[index]
		var step := recipe.steps[index]
		var step_score := _score_step(event, step, result.explanation_tags)
		matches += step_score
		source_quality = minf(source_quality, event.source_quality)
	result.score = (matches / float(recipe.steps.size())) * source_quality
	if source_quality < 0.9:
		result.explanation_tags.append(&"damaged_source")
	if process.events.size() != recipe.steps.size():
		result.explanation_tags.append(&"step_count_mismatch")

	if result.score >= 0.95:
		result.quality = RecipeResolution.Quality.PURE
	elif result.score >= 1.0 - recipe.acceptable_error:
		result.quality = RecipeResolution.Quality.WORKING
	elif result.score >= 0.45:
		result.quality = RecipeResolution.Quality.UNSTABLE
	else:
		result.quality = RecipeResolution.Quality.SPOILED
	return result


func _score_step(event: CookingProcessEvent, step: RecipeStepDefinition, reasons: Array[StringName]) -> float:
	var criteria := 0.0
	var score := 0.0
	criteria += 1.0
	if event.operation == step.operation:
		score += 1.0
	else:
		reasons.append(&"wrong_operation")
	if step.ingredient_tag != &"":
		criteria += 1.0
		if step.ingredient_tag in event.ingredient_tags:
			score += 1.0
		else:
			reasons.append(&"wrong_ingredient_trait")
	criteria += 3.0
	if event.amount >= step.minimum_amount and event.amount <= step.maximum_amount:
		score += 1.0
	else:
		reasons.append(&"amount_out_of_range")
	if event.temperature >= step.minimum_temperature and event.temperature <= step.maximum_temperature:
		score += 1.0
	else:
		reasons.append(&"temperature_out_of_range")
	if event.duration >= step.minimum_duration and event.duration <= step.maximum_duration:
		score += 1.0
	else:
		reasons.append(&"duration_out_of_range")
	if event.stir_count >= 0:
		criteria += 1.0
		if event.stir_count >= step.minimum_stirs and event.homogeneity >= step.minimum_homogeneity:
			score += 1.0
		else:
			reasons.append(&"insufficient_stirring")
	if event.overheat_duration >= 0.0:
		criteria += 1.0
		if event.overheat_duration <= step.maximum_overheat_duration:
			score += 1.0
		else:
			reasons.append(&"overheated")
	return score / criteria
