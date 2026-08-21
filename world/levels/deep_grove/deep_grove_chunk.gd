class_name DeepGroveChunk
extends Node3D

@onready var spores: GPUParticles3D = %Spores
@onready var grove_glow: OmniLight3D = %GroveGlow
@onready var spore_tide: SporeTideOrchestrator = %SporeTideOrchestrator


func _ready() -> void:
	spore_tide.state_changed.connect(_on_tide_state_changed)


func get_narrative_clues() -> Array[Node]:
	var result: Array[Node] = []
	for node: Node in find_children("*", "StaticBody3D", true, false):
		if node.has_signal("discovered"):
			result.append(node)
	return result


func get_emberberries() -> Array[HarvestableIngredient]:
	var result: Array[HarvestableIngredient] = []
	for node: Node in find_children("*", "HarvestableIngredient", true, false):
		var ingredient := node as HarvestableIngredient
		if ingredient.definition_id == &"ingredient.emberberry":
			result.append(ingredient)
	return result


func set_spore_vision_active(value: bool) -> void:
	for clue: Node in get_narrative_clues():
		if clue.has_method("set_spore_vision_active"):
			clue.call("set_spore_vision_active", value)


func _on_tide_state_changed(state: int, _label: String) -> void:
	var state_ids: Array[StringName] = [&"calm", &"rising", &"surge"]
	for clue: Node in get_narrative_clues():
		if clue.has_method("set_world_state"):
			clue.call("set_world_state", state_ids[state])
	match state:
		SporeTideOrchestrator.State.CALM:
			spores.amount = 90
			grove_glow.light_energy = 1.5
		SporeTideOrchestrator.State.RISING:
			spores.amount = 210
			grove_glow.light_energy = 2.8
		_:
			spores.amount = 420
			grove_glow.light_energy = 4.5
