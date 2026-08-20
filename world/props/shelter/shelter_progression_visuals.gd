class_name ShelterProgressionVisuals
extends Node3D

@onready var research_wall: Node3D = %ResearchWall
@onready var grove_samples: Node3D = %GroveSamples

var _loop: GameLoopOrchestrator


func setup(loop: GameLoopOrchestrator) -> void:
	_loop = loop
	loop.stage_changed.connect(_on_loop_changed)
	_refresh()


func _on_loop_changed(_stage: int, _objective: String) -> void:
	_refresh()


func _refresh() -> void:
	if _loop == null:
		return
	research_wall.visible = _loop.route_unlocked
	grove_samples.visible = _loop.second_expedition_complete

