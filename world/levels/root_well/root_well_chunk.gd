class_name RootWellChunk
extends Node3D

@onready var pressure: RootPressureOrchestrator = %RootPressureOrchestrator
@onready var warded_route: Node3D = %WardedRoute
@onready var resonant_route: Node3D = %ResonantRoute
@onready var resonant_tracers: Node3D = %ResonantTracers
@onready var hunting_particles: GPUParticles3D = %HuntingParticles
@onready var heart_light: OmniLight3D = %HeartLight

var _loop: GameLoopOrchestrator


func _ready() -> void:
	pressure.state_changed.connect(_on_pressure_state_changed)


func setup(loop: GameLoopOrchestrator, player: FirstPersonController) -> void:
	_loop = loop
	pressure.setup(player, self)
	loop.root_well_plan_changed.connect(_on_plan_changed)
	_apply_plan(loop.root_well_plan)


func get_narrative_clues() -> Array[Node]:
	var result: Array[Node] = []
	for node: Node in find_children("*", "StaticBody3D", true, false):
		if node.has_signal("discovered"):
			result.append(node)
	return result


func set_spore_vision_active(value: bool) -> void:
	resonant_tracers.visible = value or (_loop != null and _loop.root_well_plan == &"resonant_descent")


func _on_plan_changed(plan_id: StringName, _title: String) -> void:
	_apply_plan(plan_id)


func _apply_plan(plan_id: StringName) -> void:
	pressure.set_plan(plan_id)
	_set_route_enabled(warded_route, plan_id == &"warded_descent")
	_set_route_enabled(resonant_route, plan_id == &"resonant_descent")
	resonant_tracers.visible = plan_id == &"resonant_descent"


func _set_route_enabled(route: Node3D, enabled: bool) -> void:
	route.visible = enabled
	for body: Node in route.find_children("*", "StaticBody3D", true, false):
		(body as StaticBody3D).collision_layer = 1 if enabled else 0


func _on_pressure_state_changed(state: int, _label: String) -> void:
	hunting_particles.amount = 75 if state == RootPressureOrchestrator.State.REST else (180 if state == RootPressureOrchestrator.State.LISTENING else 360)
	heart_light.light_energy = 1.4 if state == RootPressureOrchestrator.State.REST else (2.8 if state == RootPressureOrchestrator.State.LISTENING else 5.2)
