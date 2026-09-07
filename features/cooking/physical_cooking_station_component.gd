class_name PhysicalCookingStationComponent
extends Node

@export_enum("add_water", "add_kvass", "add_spirit", "transfer", "cycle_heat", "stir", "bottle", "distill", "serve", "vessel_position", "bellows", "hourglass") var role: String = "add_water"

var orchestrator: CookingOrchestrator
@onready var interactable: InteractableComponent = get_parent().get_node("InteractableComponent") as InteractableComponent


func _ready() -> void:
	interactable.interaction_completed.connect(_on_interaction_completed)
	interactable.alternative_requested.connect(_on_alternative_requested)


func setup(value: CookingOrchestrator) -> void:
	orchestrator = value
	orchestrator.vessel_state_changed.connect(_update_prompt)
	_update_prompt(orchestrator.vessel)


func _on_interaction_completed(actor: Node, _action: StringName) -> void:
	if orchestrator == null:
		return
	match role:
		"add_water":
			orchestrator.add_water()
		"add_kvass":
			orchestrator.add_base(&"base.kvass")
		"add_spirit":
			orchestrator.add_base(&"base.spirit")
		"transfer":
			orchestrator.transfer_prepared_ingredient()
		"cycle_heat":
			orchestrator.cycle_heat()
		"stir":
			orchestrator.stir_vessel()
		"bottle":
			orchestrator.bottle_result(actor)
		"distill":
			orchestrator.distill_result(actor)
		"serve":
			orchestrator.serve_result(actor)
		"vessel_position":
			orchestrator.toggle_vessel_position()
		"bellows":
			orchestrator.pump_bellows()
		"hourglass":
			orchestrator.flip_hourglass()


func _on_alternative_requested(_actor: Node) -> void:
	if orchestrator != null and role == "transfer":
		orchestrator.discard_batch()


func _update_prompt(state: ThermalVesselState) -> void:
	match role:
		"add_water":
			interactable.primary_verb = "Налить родниковую воду"
		"add_kvass":
			interactable.primary_verb = "Налить кислый квас"
		"add_spirit":
			interactable.primary_verb = "Налить хлебный спирт"
		"transfer":
			interactable.primary_verb = "Переложить крошку в котёл · [СКМ] вылить состав"
		"cycle_heat":
			var names := ["Погасить", "Зажечь слабый огонь", "Усилить огонь"]
			interactable.primary_verb = names[wrapi(state.heat_level + 1, 0, 3)]
		"stir":
			interactable.primary_verb = "Помешать состав (%d раз)" % state.stir_count
		"bottle":
			interactable.primary_verb = "Забрать готовый состав" if orchestrator.pending_result != null else "Разлить готовый состав"
		"distill":
			interactable.primary_verb = "Перегнать через змеевик"
		"serve":
			interactable.primary_verb = "Снять походную порцию"
		"vessel_position":
			interactable.primary_verb = "Поднять котёл" if state.vessel_position == ThermalVesselState.VesselPosition.LOWERED else "Опустить котёл к огню"
		"bellows":
			interactable.primary_verb = "Качнуть мехи (%d)" % state.bellows_pulls
		"hourglass":
			interactable.primary_verb = "Песок идёт…" if state.hourglass_running else "Перевернуть песочные часы (%d)" % state.completed_hourglass_turns
