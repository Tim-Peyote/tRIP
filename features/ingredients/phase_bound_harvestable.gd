class_name PhaseBoundHarvestable
extends HarvestableIngredient

@export var required_effect_channel: StringName = &"spore_vision"

var _phase_available: bool = false
var _pulse_time: float = 0.0
var _rest_scale: Vector3


func _ready() -> void:
	super()
	_rest_scale = scale
	_apply_phase_available(false)


func _process(delta: float) -> void:
	_pulse_time += delta
	var pulse := 1.0 + sin(_pulse_time * 2.7) * 0.035
	scale = _rest_scale * Vector3(pulse, 1.0 + sin(_pulse_time * 2.1) * 0.018, pulse)
	var glow := get_node_or_null("Glow") as OmniLight3D
	if glow != null:
		glow.light_energy = 1.05 + sin(_pulse_time * 4.2) * 0.24


func set_spore_vision_active(value: bool) -> void:
	if required_effect_channel == &"spore_vision":
		_apply_phase_available(value)


func is_phase_available() -> bool:
	return _phase_available


func _apply_phase_available(value: bool) -> void:
	_phase_available = value
	visible = value
	collision_layer = 4 if value else 0
	process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
