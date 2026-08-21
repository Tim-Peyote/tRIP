class_name HypothesisOrchestrator
extends Node

signal hypothesis_updated(hypothesis_id: StringName, is_verified: bool)

var _knowledge: KnowledgeOrchestrator
var _hypotheses: Array[HypothesisDefinition] = []
var _verified: Dictionary[StringName, bool] = {}


func setup(knowledge: KnowledgeOrchestrator) -> void:
	_knowledge = knowledge
	_hypotheses.clear()
	for definition: ContentDefinition in ContentDB.get_all():
		if definition is HypothesisDefinition:
			_hypotheses.append(definition as HypothesisDefinition)
	knowledge.clue_recorded.connect(_on_clue_recorded)
	_evaluate_all()


func is_verified(hypothesis_id: StringName) -> bool:
	return bool(_verified.get(hypothesis_id, false))


func get_display_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for hypothesis: HypothesisDefinition in _hypotheses:
		var found := 0
		for clue_id: StringName in hypothesis.required_observation_ids:
			if _knowledge.has_clue(clue_id):
				found += 1
		var status := "ПОДТВЕРЖДЕНО" if is_verified(hypothesis.id) else "%d/%d признаков" % [found, hypothesis.required_observation_ids.size()]
		lines.append("%s — %s" % [hypothesis.question, status])
	return lines


func get_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hypothesis: HypothesisDefinition in _hypotheses:
		var found_ids: Array[StringName] = []
		for clue_id: StringName in hypothesis.required_observation_ids:
			if _knowledge.has_clue(clue_id):
				found_ids.append(clue_id)
		result.append({
			"id": hypothesis.id,
			"question": hypothesis.question,
			"description": hypothesis.description,
			"verified": is_verified(hypothesis.id),
			"found_ids": found_ids,
			"required_ids": hypothesis.required_observation_ids,
			"suggested_item_ids": hypothesis.suggested_item_ids,
			"region_id": hypothesis.approximate_region_id,
		})
	return result


func _on_clue_recorded(_definition_id: StringName, _clue_id: StringName, _found: int, _total: int) -> void:
	_evaluate_all()


func _evaluate_all() -> void:
	for hypothesis: HypothesisDefinition in _hypotheses:
		var verified := not hypothesis.required_observation_ids.is_empty()
		for clue_id: StringName in hypothesis.required_observation_ids:
			if not _knowledge.has_clue(clue_id):
				verified = false
				break
		if verified != is_verified(hypothesis.id):
			_verified[hypothesis.id] = verified
			hypothesis_updated.emit(hypothesis.id, verified)
