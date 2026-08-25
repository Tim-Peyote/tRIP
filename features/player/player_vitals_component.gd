class_name PlayerVitalsComponent
extends Node

signal state_changed(snapshot: Dictionary)
signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal food_slots_changed(slots: Array[Dictionary])
signal condition_changed(condition_id: StringName, title: String)
signal damaged(amount: float, source: StringName)
signal exhausted
signal incapacitated(source: StringName)

const MAX_FOOD_SLOTS: int = 3
const NORMAL_CORE_TEMPERATURE: float = 36.7

@export_range(1.0, 300.0, 1.0) var base_maximum_health: float = 35.0
@export_range(1.0, 300.0, 1.0) var base_maximum_stamina: float = 60.0
@export_range(0.0, 20.0, 0.1, "suffix:/s") var base_stamina_regeneration: float = 9.0
@export_range(0.0, 10.0, 0.05, "suffix:/s") var base_health_regeneration: float = 0.15
@export_range(0.0, 10.0, 0.1, "suffix:s") var stamina_regeneration_delay: float = 0.85

var current_health: float = 35.0
var current_stamina: float = 60.0
var core_temperature: float = NORMAL_CORE_TEMPERATURE
var wetness: float = 0.0
var toxicity: float = 0.0
var spore_load: float = 0.0
var rested: float = 0.0
var ambient_temperature: float = 12.0
var wind_strength: float = 0.0
var active_foods: Array[Dictionary] = []

var _effect_channels: Dictionary[StringName, float] = {}
var _external_spore_exposure: float = 0.0
var _stamina_regeneration_block: float = 0.0
var _health_regeneration_block: float = 0.0
var _last_condition: StringName = &"normal"
var _last_snapshot: Dictionary = {}
var _activity_sprinting: bool = false
var _activity_moving: bool = false
var _state_emit_accumulator: float = 0.0
var _incapacitated_latched: bool = false


func _ready() -> void:
	var player := get_parent() as FirstPersonController
	if player != null:
		# This component is above InventoryComponent in the scene tree, so the
		# parent's @onready reference is not populated yet during our _ready().
		var inventory := player.get_node("InventoryComponent") as InventoryComponent
		inventory.set_consumption_guard(can_consume)
		inventory.consumable_consumed.connect(_on_consumable_consumed)
	current_health = get_maximum_health()
	current_stamina = get_maximum_stamina()
	set_process(true)
	_emit_state(true)


func _process(delta: float) -> void:
	_tick_food(delta)
	_tick_temperature(delta)
	_tick_spores_and_toxicity(delta)
	_tick_regeneration(delta)
	_state_emit_accumulator += delta
	if _state_emit_accumulator >= 0.1:
		_state_emit_accumulator = 0.0
		_emit_state()


func set_activity(sprinting: bool, moving: bool, delta: float) -> void:
	_activity_sprinting = sprinting
	_activity_moving = moving
	if sprinting and moving:
		spend_stamina((10.5 + wind_strength * 0.18) * delta, &"sprint")
	elif not moving:
		rested = move_toward(rested, 1.0, delta * 0.012)
	else:
		rested = move_toward(rested, 0.0, delta * 0.035)


func can_sprint() -> bool:
	return can_act() and current_stamina > 1.0 and core_temperature > 34.25 and toxicity < 0.94


func can_act() -> bool:
	return current_health > 0.0


func spend_stamina(amount: float, _source: StringName = &"activity") -> bool:
	if amount <= 0.0:
		return true
	if current_stamina + 0.001 < amount:
		if current_stamina > 0.0:
			current_stamina = 0.0
			stamina_changed.emit(current_stamina, get_maximum_stamina())
		exhausted.emit()
		_stamina_regeneration_block = stamina_regeneration_delay
		return false
	current_stamina -= amount
	_stamina_regeneration_block = stamina_regeneration_delay
	stamina_changed.emit(current_stamina, get_maximum_stamina())
	return true


func apply_damage(amount: float, source: StringName = &"unknown") -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	_health_regeneration_block = 4.0
	damaged.emit(amount, source)
	health_changed.emit(current_health, get_maximum_health())
	if current_health <= 0.0 and not _incapacitated_latched:
		_incapacitated_latched = true
		incapacitated.emit(source)


func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	current_health = minf(get_maximum_health(), current_health + amount)
	if current_health > 0.0:
		_incapacitated_latched = false
	health_changed.emit(current_health, get_maximum_health())


func set_environment(p_wetness: float, p_wind_strength: float, p_ambient_temperature: float) -> void:
	wetness = clampf(p_wetness, 0.0, 1.0)
	wind_strength = maxf(0.0, p_wind_strength)
	ambient_temperature = clampf(p_ambient_temperature, -45.0, 45.0)


func set_spore_exposure(value: float) -> void:
	_external_spore_exposure = clampf(value, 0.0, 1.0)


func apply_effect_channels(channels: Dictionary[StringName, float]) -> void:
	_effect_channels = channels.duplicate()


func can_consume(definition: ConsumableDefinition, _item: ItemInstance = null) -> bool:
	if not definition.occupies_food_slot:
		return true
	for slot: Dictionary in active_foods:
		if StringName(slot.get("group", &"")) == definition.nutrition_group:
			return true
	return active_foods.size() < MAX_FOOD_SLOTS


func get_maximum_health() -> float:
	return base_maximum_health + _food_total(&"maximum_health_bonus")


func get_maximum_stamina() -> float:
	return base_maximum_stamina + _food_total(&"maximum_stamina_bonus")


func get_movement_multiplier() -> float:
	if not can_act():
		return 0.0
	var value := 1.0
	if current_stamina <= 0.0:
		value *= 0.72
	if core_temperature < 36.0:
		value *= lerpf(0.68, 1.0, inverse_lerp(34.0, 36.0, core_temperature))
	value *= lerpf(1.0, 0.72, toxicity)
	value *= lerpf(1.0, 0.82, float(_effect_channels.get(&"movement_drag", 0.0)))
	return clampf(value, 0.48, 1.15)


func get_snapshot() -> Dictionary:
	return {
		"health": current_health,
		"maximum_health": get_maximum_health(),
		"stamina": current_stamina,
		"maximum_stamina": get_maximum_stamina(),
		"core_temperature": core_temperature,
		"wetness": wetness,
		"toxicity": toxicity,
		"spore_load": spore_load,
		"rested": rested,
		"condition": _get_condition(),
		"food_slots": active_foods.duplicate(true),
	}


func to_save_data() -> Dictionary:
	return {
		"current_health": current_health,
		"current_stamina": current_stamina,
		"core_temperature": core_temperature,
		"wetness": wetness,
		"toxicity": toxicity,
		"spore_load": spore_load,
		"rested": rested,
		"active_foods": active_foods.duplicate(true),
	}


func apply_save_data(data: Dictionary) -> void:
	active_foods.clear()
	for raw_slot: Variant in data.get("active_foods", []):
		if raw_slot is Dictionary and active_foods.size() < MAX_FOOD_SLOTS:
			var slot := (raw_slot as Dictionary).duplicate(true)
			slot["id"] = StringName(slot.get("id", ""))
			slot["group"] = StringName(slot.get("group", "meal"))
			active_foods.append(slot)
	core_temperature = clampf(float(data.get("core_temperature", NORMAL_CORE_TEMPERATURE)), 32.0, 40.5)
	wetness = clampf(float(data.get("wetness", 0.0)), 0.0, 1.0)
	toxicity = clampf(float(data.get("toxicity", 0.0)), 0.0, 1.0)
	spore_load = clampf(float(data.get("spore_load", 0.0)), 0.0, 1.0)
	rested = clampf(float(data.get("rested", 0.0)), 0.0, 1.0)
	current_health = clampf(float(data.get("current_health", get_maximum_health())), 0.0, get_maximum_health())
	_incapacitated_latched = current_health <= 0.0
	current_stamina = clampf(float(data.get("current_stamina", get_maximum_stamina())), 0.0, get_maximum_stamina())
	food_slots_changed.emit(active_foods.duplicate(true))
	_emit_state(true)


func developer_restore() -> void:
	current_health = get_maximum_health()
	current_stamina = get_maximum_stamina()
	core_temperature = NORMAL_CORE_TEMPERATURE
	wetness = 0.0
	toxicity = 0.0
	spore_load = 0.0
	_incapacitated_latched = false
	_emit_state(true)


func recover_after_incapacitation() -> void:
	# The run continues, but collapse costs preparedness and leaves an acute burden.
	if not active_foods.is_empty():
		active_foods.remove_at(active_foods.size() - 1)
		food_slots_changed.emit(active_foods.duplicate(true))
	current_health = get_maximum_health() * 0.42
	current_stamina = get_maximum_stamina() * 0.28
	toxicity = maxf(toxicity, 0.26)
	spore_load = maxf(spore_load, 0.18)
	core_temperature = maxf(core_temperature, 35.7)
	_incapacitated_latched = false
	_emit_state(true)


func developer_set_condition(condition: StringName) -> void:
	match condition:
		&"cold": core_temperature = 35.65
		&"freezing": core_temperature = 34.4
		&"toxic": toxicity = 0.86
		&"spores": spore_load = 0.9
		&"exhausted": current_stamina = 0.0
		_: developer_restore()
	_emit_state(true)


func _on_consumable_consumed(definition_id: StringName, quality: float) -> void:
	var definition := ContentDB.get_definition(definition_id) as ConsumableDefinition
	if definition == null:
		return
	if definition.occupies_food_slot:
		_apply_food(definition, quality)
	toxicity = clampf(toxicity + definition.toxicity * lerpf(1.15, 0.85, quality), 0.0, 1.0)
	heal(definition.maximum_health_bonus * 0.18 * quality)
	_emit_state(true)


func _apply_food(definition: ConsumableDefinition, quality: float) -> void:
	var slot := {
		"id": definition.id,
		"name": definition.display_name,
		"group": definition.nutrition_group,
		"remaining": definition.nutrition_duration_seconds,
		"duration": definition.nutrition_duration_seconds,
		"maximum_health_bonus": definition.maximum_health_bonus * quality,
		"maximum_stamina_bonus": definition.maximum_stamina_bonus * quality,
		"health_regeneration": definition.health_regeneration * quality,
		"warmth_bonus": definition.warmth_bonus * quality,
		"cold_resistance_bonus": definition.cold_resistance_bonus * quality,
		"spore_resistance_bonus": definition.spore_resistance_bonus * quality,
		"quality": quality,
	}
	for index: int in active_foods.size():
		if StringName(active_foods[index].get("group", &"")) == definition.nutrition_group:
			active_foods[index] = slot
			food_slots_changed.emit(active_foods.duplicate(true))
			_reconcile_maximums()
			return
	active_foods.append(slot)
	food_slots_changed.emit(active_foods.duplicate(true))
	_reconcile_maximums()


func _tick_food(delta: float) -> void:
	var changed := false
	for index: int in range(active_foods.size() - 1, -1, -1):
		active_foods[index]["remaining"] = maxf(0.0, float(active_foods[index]["remaining"]) - delta)
		if float(active_foods[index]["remaining"]) <= 0.0:
			active_foods.remove_at(index)
			changed = true
	if changed:
		food_slots_changed.emit(active_foods.duplicate(true))
	_reconcile_maximums()


func _tick_temperature(delta: float) -> void:
	var warmth := clampf(_food_total(&"warmth_bonus"), -1.0, 1.0)
	var cold_resistance := clampf(_food_total(&"cold_resistance_bonus"), -1.0, 1.0)
	var environmental_cold := clampf(inverse_lerp(18.0, -22.0, ambient_temperature), 0.0, 1.0)
	environmental_cold += wetness * 0.46 + clampf(wind_strength / 18.0, 0.0, 0.38)
	environmental_cold *= 1.0 - clampf(cold_resistance, 0.0, 0.9)
	var target := NORMAL_CORE_TEMPERATURE - environmental_cold * 2.45 + warmth * 0.85
	core_temperature = move_toward(core_temperature, clampf(target, 33.4, 38.2), delta * (0.018 + environmental_cold * 0.035))
	if core_temperature < 34.8:
		apply_damage(delta * 0.55, &"freezing")


func _tick_spores_and_toxicity(delta: float) -> void:
	var resistance := clampf(_food_total(&"spore_resistance_bonus") + float(_effect_channels.get(&"spore_resistance", 0.0)), -1.0, 0.92)
	var spore_target := _external_spore_exposure * (1.0 - maxf(0.0, resistance))
	spore_target += float(_effect_channels.get(&"spore_vision", 0.0)) * 0.22
	spore_load = move_toward(spore_load, clampf(spore_target, 0.0, 1.0), delta * (0.055 if spore_target > spore_load else 0.025))
	var acute_toxicity := float(_effect_channels.get(&"toxicity", 0.0))
	toxicity = move_toward(toxicity, acute_toxicity * 0.72, delta * (0.012 if toxicity > acute_toxicity else 0.03))
	if toxicity > 0.82:
		apply_damage(delta * inverse_lerp(0.82, 1.0, toxicity) * 0.85, &"toxicity")


func _tick_regeneration(delta: float) -> void:
	_stamina_regeneration_block = maxf(0.0, _stamina_regeneration_block - delta)
	_health_regeneration_block = maxf(0.0, _health_regeneration_block - delta)
	var maximum_stamina := get_maximum_stamina()
	if _stamina_regeneration_block <= 0.0 and not _activity_sprinting and current_stamina < maximum_stamina:
		var missing_ratio := 1.0 - current_stamina / maxf(1.0, maximum_stamina)
		var modifier := lerpf(1.0, 0.85, wetness)
		modifier *= lerpf(1.0, 0.4, clampf(inverse_lerp(36.0, 34.0, core_temperature), 0.0, 1.0))
		modifier *= lerpf(1.0, 0.55, toxicity)
		modifier *= lerpf(1.0, 0.68, spore_load)
		modifier *= 1.0 + rested * 0.65
		current_stamina = minf(maximum_stamina, current_stamina + base_stamina_regeneration * (0.72 + missing_ratio * 0.58) * modifier * delta)
		stamina_changed.emit(current_stamina, maximum_stamina)
	var maximum_health := get_maximum_health()
	if _health_regeneration_block <= 0.0 and core_temperature >= 35.0 and toxicity < 0.82 and current_health < maximum_health:
		var food_regeneration := _food_total(&"health_regeneration")
		var modifier := lerpf(1.0, 0.5, spore_load) * (1.0 + rested * 0.5)
		current_health = minf(maximum_health, current_health + (base_health_regeneration + food_regeneration) * modifier * delta)
		health_changed.emit(current_health, maximum_health)


func _food_total(key: StringName) -> float:
	var result := 0.0
	for slot: Dictionary in active_foods:
		var duration := maxf(0.001, float(slot.get("duration", 1.0)))
		var remaining := clampf(float(slot.get("remaining", 0.0)), 0.0, duration)
		var decay := pow(remaining / duration, 0.3)
		result += float(slot.get(key, 0.0)) * decay
	return result


func _reconcile_maximums() -> void:
	current_health = clampf(current_health, 0.0, get_maximum_health())
	current_stamina = clampf(current_stamina, 0.0, get_maximum_stamina())


func _get_condition() -> StringName:
	if current_health <= 0.0: return &"incapacitated"
	if core_temperature < 35.0: return &"freezing"
	if toxicity > 0.82: return &"toxic"
	if spore_load > 0.82: return &"spore_sick"
	if current_stamina <= 0.5: return &"exhausted"
	if core_temperature < 36.0: return &"cold"
	if wetness > 0.62: return &"wet"
	return &"normal"


func _condition_title(condition: StringName) -> String:
	return {
		&"incapacitated": "БЕЗ СОЗНАНИЯ",
		&"freezing": "ЗАМЕРЗАНИЕ",
		&"toxic": "ОТРАВЛЕНИЕ",
		&"spore_sick": "СПОРОВАЯ ЛИХОРАДКА",
		&"exhausted": "ИСТОЩЕНИЕ",
		&"cold": "ХОЛОД",
		&"wet": "ПРОМОК",
		&"normal": "СТАБИЛЬНО",
	}.get(condition, String(condition).to_upper())


func _emit_state(force: bool = false) -> void:
	var condition := _get_condition()
	if condition != _last_condition:
		_last_condition = condition
		condition_changed.emit(condition, _condition_title(condition))
	var snapshot := get_snapshot()
	if force or snapshot != _last_snapshot:
		_last_snapshot = snapshot.duplicate(true)
		state_changed.emit(snapshot)
