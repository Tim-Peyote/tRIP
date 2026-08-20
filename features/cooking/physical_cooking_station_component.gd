class_name PhysicalCookingStationComponent
extends Node

@export_enum("add_water", "transfer", "cycle_heat", "stir", "bottle") var role: String = "add_water"

var orchestrator: CookingOrchestrator
@onready var interactable: InteractableComponent = get_parent().get_node("InteractableComponent") as InteractableComponent


func _ready() -> void:
	interactable.interaction_completed.connect(_on_interaction_completed)


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
		"transfer":
			orchestrator.transfer_prepared_ingredient()
		"cycle_heat":
			orchestrator.cycle_heat()
		"stir":
			orchestrator.stir_vessel()
		"bottle":
			orchestrator.bottle_result(actor)


func _update_prompt(state: ThermalVesselState) -> void:
	match role:
		"add_water":
			interactable.primary_verb = "Налить воду в котёл"
		"transfer":
			interactable.primary_verb = "Переложить крошку в котёл"
		"cycle_heat":
			var names := ["Погасить", "Зажечь слабый огонь", "Усилить огонь"]
			interactable.primary_verb = names[wrapi(state.heat_level + 1, 0, 3)]
		"stir":
			interactable.primary_verb = "Помешать состав (%d раз)" % state.stir_count
		"bottle":
			interactable.primary_verb = "Разлить готовый состав"
