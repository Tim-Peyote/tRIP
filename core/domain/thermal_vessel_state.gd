class_name ThermalVesselState
extends RefCounted

enum HeatLevel { OFF, LOW, HIGH }
enum VesselPosition { RAISED, LOWERED }
enum HeatRegime { COLD, WARM, SIMMER, BOIL, VIOLENT }

var water_amount: float = 0.0
var base_id: StringName = &""
var temperature: float = 20.0
var heat_level: HeatLevel = HeatLevel.OFF
var vessel_position: VesselPosition = VesselPosition.LOWERED
var bellows_pulls: int = 0
var fire_momentum: float = 0.0
var hourglass_running: bool = false
var hourglass_elapsed: float = 0.0
var completed_hourglass_turns: int = 0
var ingredient_loaded: bool = false
var ingredient_id: StringName
var ingredient_tags: Array[StringName] = []
var source_quality: float = 1.0
var process_elapsed: float = 0.0
var effective_target_duration: float = 0.0
var overheat_duration: float = 0.0
var stir_count: int = 0
var homogeneity: float = 0.0
var peak_temperature: float = 20.0
var target_temperature_min: float = TARGET_MIN
var target_temperature_max: float = TARGET_MAX
var required_effective_duration: float = 18.0
var required_stirs: int = 2
var required_homogeneity: float = 0.65
var allowed_overheat_duration: float = 4.0
var controlled_temperature_sum: float = 0.0
var controlled_temperature_time: float = 0.0
var target_sensory_cue: StringName = &""

const TARGET_MIN: float = 72.0
const TARGET_MAX: float = 86.0
const OVERHEAT_THRESHOLD: float = 92.0
const HOURGLASS_TURN_SECONDS: float = 8.0


func configure_recipe(recipe: RecipeDefinition) -> void:
	target_temperature_min = TARGET_MIN
	target_temperature_max = TARGET_MAX
	required_effective_duration = 18.0
	required_stirs = 2
	required_homogeneity = 0.65
	allowed_overheat_duration = 4.0
	target_sensory_cue = &""
	if recipe == null:
		return
	for step: RecipeStepDefinition in recipe.steps:
		if step.operation != &"heat":
			continue
		target_temperature_min = step.minimum_temperature
		target_temperature_max = step.maximum_temperature
		required_effective_duration = step.minimum_duration
		required_stirs = step.minimum_stirs
		required_homogeneity = step.minimum_homogeneity
		allowed_overheat_duration = step.maximum_overheat_duration
		target_sensory_cue = step.sensory_cue
		return


func add_water(amount: float) -> bool:
	return add_base(&"base.water", amount)


func add_base(id: StringName, amount: float) -> bool:
	if amount <= 0.0 or water_amount >= 1.5:
		return false
	if base_id != &"" and base_id != id:
		return false
	base_id = id
	water_amount = minf(1.5, water_amount + amount)
	return true


func add_ingredient(id: StringName, quality: float, tags: Array[StringName] = []) -> bool:
	if ingredient_loaded or water_amount <= 0.0:
		return false
	ingredient_loaded = true
	ingredient_id = id
	ingredient_tags.assign(tags)
	source_quality = clampf(quality, 0.0, 1.0)
	return true


func cycle_heat() -> HeatLevel:
	heat_level = wrapi(heat_level + 1, HeatLevel.OFF, HeatLevel.HIGH + 1) as HeatLevel
	return heat_level


func toggle_vessel_position() -> VesselPosition:
	vessel_position = VesselPosition.LOWERED if vessel_position == VesselPosition.RAISED else VesselPosition.RAISED
	return vessel_position


func pump_bellows() -> bool:
	if heat_level == HeatLevel.OFF:
		return false
	bellows_pulls += 1
	fire_momentum = clampf(fire_momentum + 0.34, 0.0, 1.0)
	return true


func flip_hourglass() -> bool:
	if hourglass_running:
		return false
	hourglass_running = true
	hourglass_elapsed = 0.0
	return true


func stir() -> bool:
	if not ingredient_loaded or water_amount <= 0.0:
		return false
	stir_count += 1
	var hot_contribution := maxf(0.38, required_homogeneity / float(maxi(required_stirs, 1)))
	homogeneity = clampf(homogeneity + (hot_contribution if temperature >= 45.0 else 0.22), 0.0, 1.0)
	return true


func simulate(delta: float) -> void:
	if hourglass_running:
		hourglass_elapsed += delta
		if hourglass_elapsed >= HOURGLASS_TURN_SECONDS:
			hourglass_running = false
			hourglass_elapsed = HOURGLASS_TURN_SECONDS
			completed_hourglass_turns += 1
	fire_momentum = move_toward(fire_momentum, 0.0, delta * 0.075)
	var target_temperature := 20.0
	var rate := 2.2
	if vessel_position == VesselPosition.RAISED and heat_level != HeatLevel.OFF:
		target_temperature = 42.0 + fire_momentum * 8.0
		rate = 2.8
	elif heat_level == HeatLevel.LOW:
		target_temperature = 84.0 + fire_momentum * 8.0
		rate = (5.4 + fire_momentum * 2.0) / maxf(water_amount, 0.35)
	elif heat_level == HeatLevel.HIGH:
		target_temperature = 112.0 + fire_momentum * 12.0
		rate = (10.5 + fire_momentum * 3.0) / maxf(water_amount, 0.35)
	temperature = move_toward(temperature, target_temperature, rate * delta)
	peak_temperature = maxf(peak_temperature, temperature)
	if not ingredient_loaded:
		return
	process_elapsed += delta
	if temperature >= target_temperature_min and temperature <= target_temperature_max:
		effective_target_duration += delta
	if temperature >= target_temperature_min:
		controlled_temperature_sum += temperature * delta
		controlled_temperature_time += delta
	if temperature > target_temperature_max + 6.0:
		overheat_duration += delta


func is_ready() -> bool:
	return ingredient_loaded and effective_target_duration >= required_effective_duration and stir_count >= required_stirs and homogeneity >= required_homogeneity


func is_ruined() -> bool:
	return overheat_duration >= allowed_overheat_duration


func get_controlled_temperature() -> float:
	if controlled_temperature_time <= 0.001:
		return peak_temperature
	return controlled_temperature_sum / controlled_temperature_time


func get_stage_text() -> String:
	if water_amount <= 0.0:
		return "КОТЁЛ ПУСТ · выбери основу"
	var base_title := get_base_title()
	var position_title := "НАД ОГНЁМ" if vessel_position == VesselPosition.LOWERED else "ПОДНЯТ"
	if not ingredient_loaded:
		return "%s · %d°C · %s · добавить образец" % [base_title, roundi(temperature), position_title]
	if is_ruined():
		return "СМЕСЬ ПЕРЕГРЕТА · запах гари"
	if is_ready():
		return "%s · %d обор. часов · можно завершать" % [get_recipe_cue_title(), completed_hourglass_turns]
	if temperature < target_temperature_min:
		return "%s · НАГРЕВ %d°C → %d–%d°C · мешать %d/%d" % [position_title, roundi(temperature), roundi(target_temperature_min), roundi(target_temperature_max), stir_count, required_stirs]
	if temperature <= target_temperature_max:
		var timer := "часы %d%%" % roundi(hourglass_elapsed / HOURGLASS_TURN_SECONDS * 100.0) if hourglass_running else "%d обор. часов" % completed_hourglass_turns
		var cue := get_recipe_cue_title() if effective_target_duration >= required_effective_duration * 0.65 else get_sensory_cue()
		return "%s · %d°C В ОКНЕ · выдержка %d/%d · %s" % [cue, roundi(temperature), roundi(effective_target_duration), roundi(required_effective_duration), timer]
	return "ВЫШЕ ОКНА %d°C > %d°C · поднять котёл или убавить огонь" % [roundi(temperature), roundi(target_temperature_max)]


func get_base_title() -> String:
	return {&"base.water": "РОДНИКОВАЯ ВОДА", &"base.kvass": "КИСЛЫЙ КВАС", &"base.spirit": "ХЛЕБНЫЙ СПИРТ"}.get(base_id, "НЕИЗВЕСТНАЯ ОСНОВА")


func get_sensory_cue() -> String:
	match get_heat_regime():
		HeatRegime.COLD: return "ЖИДКОСТЬ МОЛЧИТ"
		HeatRegime.WARM: return "ТОНКИЙ ПАР"
		HeatRegime.SIMMER: return "РЕДКИЕ ПУЗЫРИ"
		HeatRegime.BOIL: return "РОВНОЕ КИПЕНИЕ"
		_: return "БУРНОЕ КИПЕНИЕ"


func get_recipe_cue_title() -> String:
	return cue_title(target_sensory_cue) if target_sensory_cue != &"" else get_sensory_cue()


static func cue_title(cue: StringName) -> String:
	return {
		&"silver_steam": "СЕРЕБРИСТЫЙ ПАР",
		&"dark_red_steam": "ТЁМНО-КРАСНЫЙ ПАР",
		&"iron_thump": "ГЛУХОЙ ЖЕЛЕЗНЫЙ УДАР",
		&"rim_crystal": "КРИСТАЛЛ НА КРОМКЕ",
		&"fading_chime": "ЗАТИХАЮЩИЙ ЗВОН",
		&"mirror_steam": "ПАР ПОВТОРЯЕТ ДВИЖЕНИЕ",
		&"heavy_bubble": "ТЯЖЁЛЫЙ ПУЗЫРЬ",
		&"double_steam_pulse": "ДВОЙНОЙ ПУЛЬС ПАРА",
	}.get(cue, String(cue).replace("_", " ").to_upper())


func get_heat_regime() -> HeatRegime:
	if temperature < 42.0: return HeatRegime.COLD
	if temperature < 68.0: return HeatRegime.WARM
	if temperature < 88.0: return HeatRegime.SIMMER
	if temperature < 98.0: return HeatRegime.BOIL
	return HeatRegime.VIOLENT


func reset() -> void:
	water_amount = 0.0
	base_id = &""
	temperature = 20.0
	heat_level = HeatLevel.OFF
	vessel_position = VesselPosition.LOWERED
	bellows_pulls = 0
	fire_momentum = 0.0
	hourglass_running = false
	hourglass_elapsed = 0.0
	completed_hourglass_turns = 0
	ingredient_loaded = false
	ingredient_id = &""
	ingredient_tags.clear()
	source_quality = 1.0
	process_elapsed = 0.0
	effective_target_duration = 0.0
	overheat_duration = 0.0
	stir_count = 0
	homogeneity = 0.0
	peak_temperature = 20.0
	controlled_temperature_sum = 0.0
	controlled_temperature_time = 0.0


func to_save_data() -> Dictionary:
	return {
		"water_amount": water_amount,
		"base_id": String(base_id),
		"temperature": temperature,
		"heat_level": int(heat_level),
		"vessel_position": int(vessel_position),
		"bellows_pulls": bellows_pulls,
		"fire_momentum": fire_momentum,
		"hourglass_running": hourglass_running,
		"hourglass_elapsed": hourglass_elapsed,
		"completed_hourglass_turns": completed_hourglass_turns,
		"ingredient_loaded": ingredient_loaded,
		"ingredient_id": String(ingredient_id),
		"ingredient_tags": ingredient_tags.map(func(value: StringName) -> String: return String(value)),
		"source_quality": source_quality,
		"process_elapsed": process_elapsed,
		"effective_target_duration": effective_target_duration,
		"overheat_duration": overheat_duration,
		"stir_count": stir_count,
		"homogeneity": homogeneity,
		"peak_temperature": peak_temperature,
		"controlled_temperature_sum": controlled_temperature_sum,
		"controlled_temperature_time": controlled_temperature_time,
	}


func apply_save_data(data: Dictionary) -> void:
	water_amount = clampf(float(data.get("water_amount", 0.0)), 0.0, 1.5)
	base_id = StringName(data.get("base_id", "base.water" if water_amount > 0.0 else ""))
	temperature = clampf(float(data.get("temperature", 20.0)), -20.0, 150.0)
	heat_level = clampi(int(data.get("heat_level", HeatLevel.OFF)), HeatLevel.OFF, HeatLevel.HIGH) as HeatLevel
	vessel_position = clampi(int(data.get("vessel_position", VesselPosition.LOWERED)), VesselPosition.RAISED, VesselPosition.LOWERED) as VesselPosition
	bellows_pulls = maxi(0, int(data.get("bellows_pulls", 0)))
	fire_momentum = clampf(float(data.get("fire_momentum", 0.0)), 0.0, 1.0)
	hourglass_running = bool(data.get("hourglass_running", false))
	hourglass_elapsed = clampf(float(data.get("hourglass_elapsed", 0.0)), 0.0, HOURGLASS_TURN_SECONDS)
	completed_hourglass_turns = maxi(0, int(data.get("completed_hourglass_turns", 0)))
	ingredient_loaded = bool(data.get("ingredient_loaded", false))
	ingredient_id = StringName(data.get("ingredient_id", ""))
	ingredient_tags.clear()
	for raw_tag: Variant in data.get("ingredient_tags", []):
		ingredient_tags.append(StringName(raw_tag))
	source_quality = clampf(float(data.get("source_quality", 1.0)), 0.0, 1.0)
	process_elapsed = maxf(0.0, float(data.get("process_elapsed", 0.0)))
	effective_target_duration = maxf(0.0, float(data.get("effective_target_duration", 0.0)))
	overheat_duration = maxf(0.0, float(data.get("overheat_duration", 0.0)))
	stir_count = maxi(0, int(data.get("stir_count", 0)))
	homogeneity = clampf(float(data.get("homogeneity", 0.0)), 0.0, 1.0)
	peak_temperature = maxf(temperature, float(data.get("peak_temperature", temperature)))
	controlled_temperature_sum = maxf(0.0, float(data.get("controlled_temperature_sum", 0.0)))
	controlled_temperature_time = maxf(0.0, float(data.get("controlled_temperature_time", 0.0)))
