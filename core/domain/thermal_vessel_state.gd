class_name ThermalVesselState
extends RefCounted

enum HeatLevel { OFF, LOW, HIGH }

var water_amount: float = 0.0
var temperature: float = 20.0
var heat_level: HeatLevel = HeatLevel.OFF
var ingredient_loaded: bool = false
var ingredient_id: StringName
var source_quality: float = 1.0
var process_elapsed: float = 0.0
var effective_target_duration: float = 0.0
var overheat_duration: float = 0.0
var stir_count: int = 0
var homogeneity: float = 0.0
var peak_temperature: float = 20.0

const TARGET_MIN: float = 72.0
const TARGET_MAX: float = 86.0
const OVERHEAT_THRESHOLD: float = 92.0


func add_water(amount: float) -> bool:
	if amount <= 0.0 or water_amount >= 1.5:
		return false
	water_amount = minf(1.5, water_amount + amount)
	return true


func add_ingredient(id: StringName, quality: float) -> bool:
	if ingredient_loaded or water_amount <= 0.0:
		return false
	ingredient_loaded = true
	ingredient_id = id
	source_quality = clampf(quality, 0.0, 1.0)
	return true


func cycle_heat() -> HeatLevel:
	heat_level = wrapi(heat_level + 1, HeatLevel.OFF, HeatLevel.HIGH + 1) as HeatLevel
	return heat_level


func stir() -> bool:
	if not ingredient_loaded or water_amount <= 0.0:
		return false
	stir_count += 1
	homogeneity = clampf(homogeneity + (0.38 if temperature >= 45.0 else 0.22), 0.0, 1.0)
	return true


func simulate(delta: float) -> void:
	var target_temperature := 20.0
	var rate := 2.2
	if heat_level == HeatLevel.LOW:
		target_temperature = 84.0
		rate = 5.4 / maxf(water_amount, 0.35)
	elif heat_level == HeatLevel.HIGH:
		target_temperature = 112.0
		rate = 10.5 / maxf(water_amount, 0.35)
	temperature = move_toward(temperature, target_temperature, rate * delta)
	peak_temperature = maxf(peak_temperature, temperature)
	if not ingredient_loaded:
		return
	process_elapsed += delta
	if temperature >= TARGET_MIN and temperature <= TARGET_MAX:
		effective_target_duration += delta * 3.0
	if temperature > OVERHEAT_THRESHOLD:
		overheat_duration += delta
	if process_elapsed - float(stir_count) * 4.0 > 10.0:
		homogeneity = maxf(0.0, homogeneity - delta * 0.025)


func is_ready() -> bool:
	return ingredient_loaded and effective_target_duration >= 18.0 and homogeneity >= 0.65


func is_ruined() -> bool:
	return overheat_duration >= 4.0


func get_stage_text() -> String:
	if water_amount <= 0.0:
		return "КОТЁЛ ПУСТ · нужна вода"
	if not ingredient_loaded:
		return "ВОДА %d°C · добавить измельчённый образец" % roundi(temperature)
	if is_ruined():
		return "СМЕСЬ ПЕРЕГРЕТА · запах гари"
	if is_ready():
		return "СЕРЕБРИСТЫЙ ПАР · можно разливать"
	if temperature < TARGET_MIN:
		return "НАГРЕВ %d°C · однородность %d%%" % [roundi(temperature), roundi(homogeneity * 100.0)]
	if temperature <= TARGET_MAX:
		return "НУЖНЫЙ РЕЖИМ %d°C · выдержка %ds" % [roundi(temperature), roundi(effective_target_duration)]
	return "СЛИШКОМ ГОРЯЧО %d°C · убавить огонь" % roundi(temperature)


func reset() -> void:
	water_amount = 0.0
	temperature = 20.0
	heat_level = HeatLevel.OFF
	ingredient_loaded = false
	ingredient_id = &""
	source_quality = 1.0
	process_elapsed = 0.0
	effective_target_duration = 0.0
	overheat_duration = 0.0
	stir_count = 0
	homogeneity = 0.0
	peak_temperature = 20.0


func to_save_data() -> Dictionary:
	return {
		"water_amount": water_amount,
		"temperature": temperature,
		"heat_level": int(heat_level),
		"ingredient_loaded": ingredient_loaded,
		"ingredient_id": String(ingredient_id),
		"source_quality": source_quality,
		"process_elapsed": process_elapsed,
		"effective_target_duration": effective_target_duration,
		"overheat_duration": overheat_duration,
		"stir_count": stir_count,
		"homogeneity": homogeneity,
		"peak_temperature": peak_temperature,
	}


func apply_save_data(data: Dictionary) -> void:
	water_amount = clampf(float(data.get("water_amount", 0.0)), 0.0, 1.5)
	temperature = clampf(float(data.get("temperature", 20.0)), -20.0, 150.0)
	heat_level = clampi(int(data.get("heat_level", HeatLevel.OFF)), HeatLevel.OFF, HeatLevel.HIGH) as HeatLevel
	ingredient_loaded = bool(data.get("ingredient_loaded", false))
	ingredient_id = StringName(data.get("ingredient_id", ""))
	source_quality = clampf(float(data.get("source_quality", 1.0)), 0.0, 1.0)
	process_elapsed = maxf(0.0, float(data.get("process_elapsed", 0.0)))
	effective_target_duration = maxf(0.0, float(data.get("effective_target_duration", 0.0)))
	overheat_duration = maxf(0.0, float(data.get("overheat_duration", 0.0)))
	stir_count = maxi(0, int(data.get("stir_count", 0)))
	homogeneity = clampf(float(data.get("homogeneity", 0.0)), 0.0, 1.0)
	peak_temperature = maxf(temperature, float(data.get("peak_temperature", temperature)))
