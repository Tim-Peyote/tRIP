class_name ExpeditionObjectiveOrchestrator
extends Node

signal objective_updated(text: String)
signal notice_requested(text: String)
signal completed

enum Stage { SEEK_MOONCAP, RETURN_TO_SHELTER, COMPLETE }

var stage: Stage = Stage.SEEK_MOONCAP


func get_objective_text() -> String:
	match stage:
		Stage.SEEK_MOONCAP:
			return "ВЫЛАЗКА 01 · найти и срезать шляпку лунного гриба"
		Stage.RETURN_TO_SHELTER:
			return "ОБРАЗЕЦ ПОЛУЧЕН · вернуться в убежище"
		_:
			return "ВЫЛАЗКА ЗАВЕРШЕНА · образец готов к исследованию"


func record_harvest(item: ItemInstance) -> void:
	if item == null or stage != Stage.SEEK_MOONCAP:
		return
	if item.definition_id == &"ingredient.false_mooncap":
		notice_requested.emit("Похожий гриб, но рисунок спор другой. Цель не выполнена.")
		return
	if item.definition_id == &"ingredient.mooncap" and item.processing_state.get(&"part", &"") == &"cap":
		stage = Stage.RETURN_TO_SHELTER
		objective_updated.emit(get_objective_text())


func record_return(_actor: Node) -> void:
	if stage != Stage.RETURN_TO_SHELTER:
		return
	stage = Stage.COMPLETE
	objective_updated.emit(get_objective_text())
	completed.emit()
