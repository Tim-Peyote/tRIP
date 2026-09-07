class_name CookingStationVisuals
extends Node3D

@onready var mortar_contents: MeshInstance3D = %MortarContents
@onready var active_liquid: MeshInstance3D = %ActiveLiquid
@onready var steam: Node3D = %Steam
@onready var fire_glow: OmniLight3D = %FireGlow
@onready var fire_mesh: MeshInstance3D = %FireMesh
@onready var pestle: Node3D = %Pestle
@onready var water_jug: Node3D = %WaterJug
@onready var ladle: Node3D = %Ladle

var _time: float = 0.0
var _result_latched: bool = false
var _tool_tween: Tween
var _tool_tweens: Dictionary = {}
var _pestle_rest: Transform3D
var _jug_rest: Transform3D
var _ladle_rest: Transform3D
var _cauldron: Node3D
var _cauldron_rest: Transform3D
var _liquid_offset: Vector3
var _steam_offset: Vector3
var _hourglass: Node3D
var _hourglass_rest: Transform3D
var _bellows: Node3D
var _bellows_rest: Transform3D


func _ready() -> void:
	preload("res://presentation/materials/laboratory_surface_library.gd").apply_to(get_parent())
	refresh_rest_transforms()


func refresh_rest_transforms() -> void:
	_pestle_rest = pestle.transform
	_jug_rest = water_jug.transform
	_ladle_rest = ladle.transform
	_cauldron = get_parent().get_node_or_null("Cauldron") as Node3D
	_hourglass = get_parent().get_node_or_null("Hourglass") as Node3D
	_bellows = get_parent().get_node_or_null("Bellows") as Node3D
	if _bellows != null and _bellows.has_node("AuthoredBellows"):
		_bellows = _bellows.get_node("AuthoredBellows") as Node3D
	if _cauldron != null:
		_cauldron_rest = _cauldron.transform
		_liquid_offset = active_liquid.position - _cauldron.position
		_steam_offset = steam.position - _cauldron.position
	if _hourglass != null: _hourglass_rest = _hourglass.transform
	if _bellows != null: _bellows_rest = _bellows.transform


func setup(orchestrator: CookingOrchestrator) -> void:
	orchestrator.action_recorded.connect(_on_action_recorded)
	orchestrator.action_rejected.connect(_on_action_rejected)
	orchestrator.result_created.connect(_on_result_created)
	orchestrator.vessel_state_changed.connect(_on_vessel_state_changed)
	orchestrator.physical_action_recorded.connect(_on_physical_action_recorded)
	orchestrator.process_reset.connect(func() -> void:
		_result_latched = false
		mortar_contents.visible = false
		_on_vessel_state_changed(orchestrator.vessel)
	)
	_on_vessel_state_changed(orchestrator.vessel)


func _process(delta: float) -> void:
	# Presentation nodes share the lab root, but must follow the crane's pot.
	if is_instance_valid(_cauldron):
		active_liquid.position = _cauldron.position + _liquid_offset
		steam.position = _cauldron.position + _steam_offset
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
	# Rejected input must not change the physical appearance of a hot vessel.
	pass


func _on_result_created(_result: RecipeResolution, _display_name: String) -> void:
	_result_latched = true
	active_liquid.visible = true
	steam.visible = true


func _on_vessel_state_changed(state: ThermalVesselState) -> void:
	active_liquid.visible = state.water_amount > 0.0
	steam.visible = state.ingredient_loaded and state.temperature >= 58.0
	fire_mesh.visible = state.heat_level != ThermalVesselState.HeatLevel.OFF
	fire_glow.visible = fire_mesh.visible
	fire_glow.light_energy = (1.2 if state.heat_level == ThermalVesselState.HeatLevel.LOW else 2.4) + state.fire_momentum * 1.1
	fire_mesh.scale = Vector3.ONE * (1.0 + state.fire_momentum * 0.28)
	steam.scale = Vector3.ONE * lerpf(0.65, 1.5, inverse_lerp(52.0, 102.0, state.temperature))
	if active_liquid.visible:
		var material := active_liquid.material_override as StandardMaterial3D
		if material != null:
			var heat_t := inverse_lerp(20.0, 100.0, state.temperature)
			if state.ingredient_id == &"ingredient.emberberry":
				material.albedo_color = Color(0.22, 0.045, 0.025).lerp(Color(0.72, 0.09, 0.018), heat_t)
				material.emission = Color(0.5, 0.035, 0.01)
			else:
				var base_color: Color = {&"base.kvass": Color(0.34, 0.15, 0.045), &"base.spirit": Color(0.16, 0.24, 0.3)}.get(state.base_id, Color(0.12, 0.22, 0.16))
				material.albedo_color = base_color.lerp(Color(0.44, 0.34, 0.09), heat_t)
				material.emission = Color(0.16, 0.29, 0.07)


func _on_physical_action_recorded(action: StringName) -> void:
	_result_latched = false
	_animate_tool(action)


func _animate_tool(action: StringName) -> void:
	var channel := action
	if action in [&"add_water", &"add_kvass", &"add_spirit"]: channel = &"jug"
	if action in [&"lower_vessel", &"raise_vessel"]: channel = &"vessel"
	var previous := _tool_tweens.get(channel) as Tween
	if previous != null and previous.is_valid(): previous.kill()
	_tool_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tool_tweens[channel] = _tool_tween
	match action:
		&"add_water", &"add_kvass", &"add_spirit":
			_tool_tween.tween_property(water_jug, "rotation:z", -0.9, 0.22)
			_tool_tween.tween_property(water_jug, "rotation:z", _jug_rest.basis.get_euler().z, 0.3)
		&"stir":
			_tool_tween.tween_property(ladle, "rotation:y", _ladle_rest.basis.get_euler().y + 1.7, 0.28)
			_tool_tween.tween_property(ladle, "rotation:y", _ladle_rest.basis.get_euler().y, 0.26)
		&"transfer":
			_tool_tween.tween_property(pestle, "position:y", _pestle_rest.origin.y + 0.18, 0.18)
			_tool_tween.tween_property(pestle, "position:y", _pestle_rest.origin.y, 0.24)
		&"lower_vessel", &"raise_vessel":
			if _cauldron != null:
				var offset := -0.18 if action == &"lower_vessel" else 0.18
				_tool_tween.tween_property(_cauldron, "position:y", _cauldron_rest.origin.y + offset, 0.32)
		&"bellows":
			if _bellows != null:
				_tool_tween.tween_property(_bellows, "scale:z", _bellows_rest.basis.get_scale().z * 0.55, 0.14)
				_tool_tween.tween_property(_bellows, "scale:z", _bellows_rest.basis.get_scale().z, 0.22)
		&"hourglass":
			if _hourglass != null:
				_tool_tween.tween_property(_hourglass, "rotation:z", _hourglass.rotation.z + PI, 0.35)
		_:
			# Fire/collection notifications are not mortar strokes.
			_tool_tween.kill()
