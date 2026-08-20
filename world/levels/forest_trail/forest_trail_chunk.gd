class_name ForestTrailChunk
extends Node3D

@onready var spore_route: Node3D = %SporeRoute
@onready var vision_gate: SimplePortal = %VisionGate


func set_spore_vision_active(value: bool) -> void:
	spore_route.visible = value
	vision_gate.set_locked(not value)
	for node: Node in find_children("*", "StaticBody3D", true, false):
		if node.has_method("set_spore_vision_active"):
			node.call("set_spore_vision_active", value)


func get_clues() -> Array[Node]:
	var result: Array[Node] = []
	for node: Node in find_children("*", "StaticBody3D", true, false):
		if node.has_signal("discovered"):
			result.append(node)
	return result
