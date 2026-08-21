class_name PhysicalPropertyComponent
extends Node

signal wetness_changed(value: float)
signal temperature_changed(value: float)
signal reaction_triggered(reaction: StringName, strength: float)

@export var display_name: String = "Физический объект"
@export_enum("wood", "stone", "metal", "ceramic", "glass", "organic") var material_kind: String = "wood"
@export var flammable: bool = false
@export var conductive: bool = false
@export var porous: bool = true
@export var buoyant: bool = false
@export_range(0.0, 1.0, 0.01) var wetness: float = 0.0
@export_range(-60.0, 250.0, 1.0, "suffix:°C") var temperature: float = 12.0


func _ready() -> void:
	add_to_group(&"weather_reactive")
	var body := get_parent()
	if body != null:
		body.set_meta(&"interaction_name", display_name)
		body.set_meta(&"physical_material", StringName(material_kind))
		body.set_meta(&"flammable", flammable)
		body.set_meta(&"conductive", conductive)
		body.set_meta(&"wetness", wetness)


func apply_precipitation(amount: float) -> void:
	if not porous and material_kind != "metal" and material_kind != "glass":
		return
	set_wetness(wetness + amount)


func dry(amount: float) -> void:
	set_wetness(wetness - amount)


func add_heat(amount: float) -> void:
	temperature += amount
	temperature_changed.emit(temperature)
	if flammable and temperature > 90.0 and wetness < 0.35:
		reaction_triggered.emit(&"ignite", inverse_lerp(90.0, 180.0, temperature))


func apply_electricity(strength: float) -> void:
	if conductive or wetness > 0.55:
		reaction_triggered.emit(&"conduct", strength * lerpf(0.45, 1.0, wetness))


func set_wetness(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	if is_equal_approx(next, wetness):
		return
	wetness = next
	get_parent().set_meta(&"wetness", wetness)
	wetness_changed.emit(wetness)
