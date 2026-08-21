class_name InvestigationBoard
extends StaticBody3D

signal plan_preview_changed(plan_id: StringName)

const PLAN_IDS: Array[StringName] = [&"warded_descent", &"resonant_descent"]

@onready var interactable: InteractableComponent = %InteractableComponent
@onready var locked_note: Label3D = %LockedNote
@onready var warded_card: Node3D = %WardedCard
@onready var resonance_card: Node3D = %ResonanceCard
@onready var warded_marker: MeshInstance3D = %WardedMarker
@onready var resonance_marker: MeshInstance3D = %ResonanceMarker
@onready var trail_note: Node3D = %TrailNote
@onready var camp_note: Node3D = %CampNote
@onready var ring_note: Node3D = %RingNote

var _loop: GameLoopOrchestrator
var _preview_index: int = -1


func _ready() -> void:
	interactable.interaction_completed.connect(_on_interaction_completed)
	_refresh()


func setup(loop: GameLoopOrchestrator) -> void:
	_loop = loop
	loop.stage_changed.connect(_on_loop_state_changed)
	loop.root_well_plan_changed.connect(_on_plan_changed)
	_refresh()


func get_interaction_prompt(_actor: Node) -> String:
	if _loop == null or not _loop.mycologist_clues.has(&"mycologist.ring.surge_trace"):
		return "Изучить: доска расследования"
	if not _loop.counteragent_brewed:
		return "Нужен контрагент для плана спуска"
	var next_id := _get_next_plan_id()
	return "Выбрать план: %s" % _get_plan_title(next_id)


func can_receive_interaction(_actor: Node) -> bool:
	return _loop != null


func get_inspection_data() -> Dictionary:
	return {
		"title": "Доска расследования",
		"description": "Физическая карта поиска миколога. Нити связывают полевую зарубку, лагерь и координаты корневого колодца.",
	}


func preview_plan(plan_id: StringName) -> void:
	var index := PLAN_IDS.find(plan_id)
	if index < 0:
		return
	_preview_index = index
	plan_preview_changed.emit(plan_id)
	_refresh_markers()


func _on_interaction_completed(_actor: Node, _action: StringName) -> void:
	if _loop == null:
		return
	if not _loop.can_choose_root_well_plan():
		_refresh()
		return
	var next_id := _get_next_plan_id()
	_preview_index = PLAN_IDS.find(next_id)
	_loop.select_root_well_plan(next_id)
	plan_preview_changed.emit(next_id)
	_refresh()


func _get_next_plan_id() -> StringName:
	if _loop != null and _loop.root_well_plan != &"":
		var selected_index := PLAN_IDS.find(_loop.root_well_plan)
		return PLAN_IDS[(selected_index + 1) % PLAN_IDS.size()]
	if _preview_index >= 0:
		return PLAN_IDS[(_preview_index + 1) % PLAN_IDS.size()]
	return PLAN_IDS[0]


func _get_plan_title(plan_id: StringName) -> String:
	return "ТИХАЯ КРОВЬ" if plan_id == &"warded_descent" else "РЕЗОНАНС"


func _on_loop_state_changed(_stage: int, _objective: String) -> void:
	_refresh()


func _on_plan_changed(plan_id: StringName, _title: String) -> void:
	_preview_index = PLAN_IDS.find(plan_id)
	_refresh()


func _refresh() -> void:
	var has_loop := _loop != null
	var has_ring := has_loop and _loop.mycologist_clues.has(&"mycologist.ring.surge_trace")
	trail_note.visible = has_loop and _loop.mycologist_clues.has(&"mycologist.trail.notch")
	camp_note.visible = has_loop and _loop.mycologist_clues.has(&"mycologist.camp.abandoned")
	ring_note.visible = has_ring
	warded_card.visible = has_ring
	resonance_card.visible = has_ring
	locked_note.visible = not has_ring
	locked_note.text = "СЛЕДЫ НЕ СХОДЯТСЯ\nНУЖНЫ КООРДИНАТЫ КОЛЬЦА" if not has_ring else ""
	_refresh_markers()


func _refresh_markers() -> void:
	var selected := _loop.root_well_plan if _loop != null else &""
	warded_marker.visible = selected == &"warded_descent"
	resonance_marker.visible = selected == &"resonant_descent"
