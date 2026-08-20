extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ContentDB.rebuild()
	var knowledge := KnowledgeOrchestrator.new()
	var hypotheses := HypothesisOrchestrator.new()
	var view := (load("res://features/inspection/sample_inspection_view.tscn") as PackedScene).instantiate() as SampleInspectionView
	add_child(knowledge)
	add_child(hypotheses)
	add_child(view)
	hypotheses.setup(knowledge)
	view.clue_found.connect(knowledge.record_clue)
	view.inspection_completed.connect(knowledge.understand)
	_expect(view.open_definition(&"ingredient.mooncap"), "Mooncap inspection view could not open.")
	_expect(view.model_root.get_child_count() == 1, "Inspection model was not instantiated in SubViewport.")
	view.set_zoom(0.7)
	view.rotate_sample(92.0, 0.0)
	view.rotate_sample(76.0, 0.0)
	_expect(view.session.is_complete(), "Rotation and zoom did not reveal all mooncap clues.")
	_expect(knowledge.get_clue_count(&"ingredient.mooncap") == 3, "Discovered clues were not recorded in knowledge state.")
	_expect(knowledge.get_level(&"ingredient.mooncap") == KnowledgeOrchestrator.Level.UNDERSTOOD, "Complete inspection did not mark the species understood.")
	_expect(hypotheses.is_verified(&"hypothesis.mooncap_identity"), "Required observations did not verify the identity hypothesis.")
	view.close()
	_expect(not view.visible, "Inspection view did not close.")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip inspection test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip inspection test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
