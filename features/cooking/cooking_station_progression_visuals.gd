class_name CookingStationProgressionVisuals
extends Node

var _tools_by_tier: Dictionary[int, Array] = {}


func setup(cooking: CookingOrchestrator, portable_root: Node) -> void:
	_tools_by_tier = {
		1: [portable_root.get_node_or_null("Distiller"), portable_root.get_node_or_null("ServingBowl")],
		2: [portable_root.get_node_or_null("SpiritFlask")],
	}
	if not cooking.mastery_changed.is_connected(_on_mastery_changed):
		cooking.mastery_changed.connect(_on_mastery_changed)
	_on_mastery_changed(cooking.station_tier, cooking.batches_completed)


func _on_mastery_changed(tier: int, _batches_completed: int) -> void:
	for required_tier: int in _tools_by_tier:
		for raw_node: Variant in _tools_by_tier[required_tier]:
			var tool := raw_node as Node3D
			if tool == null:
				continue
			var unlocked := tier >= required_tier
			tool.visible = unlocked
			tool.process_mode = Node.PROCESS_MODE_INHERIT if unlocked else Node.PROCESS_MODE_DISABLED
			var interactable := tool.get_node_or_null("InteractableComponent") as InteractableComponent
			if interactable != null:
				interactable.enabled = unlocked
