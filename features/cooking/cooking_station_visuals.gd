class_name CookingStationVisuals
extends Node3D

@onready var mortar_contents: MeshInstance3D = %MortarContents
@onready var active_liquid: MeshInstance3D = %ActiveLiquid
@onready var steam: Node3D = %Steam
@onready var fire_glow: OmniLight3D = %FireGlow
@onready var fire_mesh: MeshInstance3D = %FireMesh

var _time: float = 0.0
var _result_latched: bool = false


func setup(orchestrator: CookingOrchestrator) -> void:
	orchestrator.action_recorded.connect(_on_action_recorded)
	orchestrator.action_rejected.connect(_on_action_rejected)
	orchestrator.result_created.connect(_on_result_created)
	orchestrator.vessel_state_changed.connect(_on_vessel_state_changed)
	orchestrator.physical_action_recorded.connect(_on_physical_action_recorded)
	_on_vessel_state_changed(orchestrator.vessel)


func _process(delta: float) -> void:
	if not steam.visible:
		return
	_time += delta
	for index in steam.get_child_count():
		var mote := steam.get_child(index) as Node3D
		mote.position.y = 0.36 + fmod(_time * (0.17 + index * 0.035) + index * 0.21, 0.72)
		mote.position.x = sin(_time * 1.4 + index * 2.0) * 0.07


func _on_action_recorded(operation: StringName, _step_count: int) -> void:
	if operation == &"grind":
		_result_latched = false
		mortar_contents.visible = true
		active_liquid.visible = false
		steam.visible = false
	elif operation == &"heat":
		mortar_contents.visible = false
		active_liquid.visible = true
		steam.visible = true


func _on_action_rejected(_reason: String) -> void:
	steam.visible = false


func _on_result_created(_result: RecipeResolution, _display_name: String) -> void:
	_result_latched = true
	active_liquid.visible = true
	steam.visible = true


func _on_vessel_state_changed(state: ThermalVesselState) -> void:
	if _result_latched and state.water_amount <= 0.0:
		return
	active_liquid.visible = state.water_amount > 0.0
	steam.visible = state.ingredient_loaded and state.temperature >= 58.0
	fire_mesh.visible = state.heat_level != ThermalVesselState.HeatLevel.OFF
	fire_glow.visible = fire_mesh.visible
	fire_glow.light_energy = 1.2 if state.heat_level == ThermalVesselState.HeatLevel.LOW else 2.4
	if active_liquid.visible:
		var material := active_liquid.material_override as StandardMaterial3D
		if material != null:
			var heat_t := inverse_lerp(20.0, 100.0, state.temperature)
			material.albedo_color = Color(0.12, 0.22, 0.16).lerp(Color(0.44, 0.34, 0.09), heat_t)


func _on_physical_action_recorded(_action: StringName) -> void:
	_result_latched = false
