class_name CookingOrchestrator
extends Node

signal action_recorded(operation: StringName, step_count: int)
signal action_rejected(reason: String)
signal process_reset
signal result_created(result: RecipeResolution, display_name: String)
signal vessel_state_changed(state: ThermalVesselState)
signal physical_action_recorded(action: StringName)
signal mastery_changed(tier: int, batches_completed: int)

@export var recipe: RecipeDefinition
@export var recipes: Array[RecipeDefinition] = []

var process := CookingProcess.new()
var vessel := ThermalVesselState.new()
var active_recipe: RecipeDefinition
var batches_completed: int = 0
var station_tier: int = 0


func _ready() -> void:
	if not recipes.is_empty():
		active_recipe = recipes[0]
	else:
		active_recipe = recipe


func _process(delta: float) -> void:
	if vessel.water_amount <= 0.0 and vessel.heat_level == ThermalVesselState.HeatLevel.OFF:
		return
	vessel.simulate(delta)
	vessel_state_changed.emit(vessel)


func add_water() -> bool:
	return add_base(&"base.water")


func add_base(base_id: StringName) -> bool:
	if not vessel.add_base(base_id, 1.0):
		action_rejected.emit("Котёл уже заполнен другой основой.")
		return false
	physical_action_recorded.emit(StringName("add_%s" % String(base_id).get_slice(".", 1)))
	vessel_state_changed.emit(vessel)
	return true


func transfer_prepared_ingredient() -> bool:
	var source: CookingProcessEvent
	for event: CookingProcessEvent in process.events:
		if event.operation == &"grind":
			source = event
	if source == null:
		action_rejected.emit("Сначала измельчи подходящий образец в ступке.")
		return false
	if not vessel.add_ingredient(source.ingredient_id, source.source_quality, source.ingredient_tags):
		action_rejected.emit("Сначала налей воду; второй образец уже не нужен.")
		return false
	physical_action_recorded.emit(&"transfer")
	vessel_state_changed.emit(vessel)
	return true


func cycle_heat() -> bool:
	var level := vessel.cycle_heat()
	physical_action_recorded.emit(StringName("heat_%d" % level))
	vessel_state_changed.emit(vessel)
	return true


func stir_vessel() -> bool:
	if not vessel.stir():
		action_rejected.emit("Нечего перемешивать.")
		return false
	physical_action_recorded.emit(&"stir")
	vessel_state_changed.emit(vessel)
	return true


func toggle_vessel_position() -> bool:
	var position := vessel.toggle_vessel_position()
	physical_action_recorded.emit(&"lower_vessel" if position == ThermalVesselState.VesselPosition.LOWERED else &"raise_vessel")
	vessel_state_changed.emit(vessel)
	return true


func pump_bellows() -> bool:
	if not vessel.pump_bellows():
		action_rejected.emit("Сначала разожги очаг.")
		return false
	physical_action_recorded.emit(&"bellows")
	vessel_state_changed.emit(vessel)
	return true


func flip_hourglass() -> bool:
	if not vessel.flip_hourglass():
		action_rejected.emit("Песок ещё не высыпался.")
		return false
	physical_action_recorded.emit(&"hourglass")
	vessel_state_changed.emit(vessel)
	return true


func bottle_result(actor: Node) -> bool:
	return finish_result(actor, RecipeDefinition.FinishMethod.BOTTLE)


func distill_result(actor: Node) -> bool:
	return finish_result(actor, RecipeDefinition.FinishMethod.DISTILL)


func serve_result(actor: Node) -> bool:
	return finish_result(actor, RecipeDefinition.FinishMethod.SERVE)


func finish_result(actor: Node, finish_method: RecipeDefinition.FinishMethod) -> bool:
	if not vessel.ingredient_loaded:
		action_rejected.emit("В котле нет состава.")
		return false
	if not vessel.is_ready() and not vessel.is_ruined():
		action_rejected.emit("Состав ещё не готов: следи за температурой, паром и однородностью.")
		return false
	var inventory := actor.find_child("InventoryComponent", true, false) as InventoryComponent
	if inventory == null:
		action_rejected.emit("Не найдена сумка игрока.")
		return false
	var event := CookingProcessEvent.new(
		&"heat",
		vessel.ingredient_id,
		1.0,
		vessel.peak_temperature,
		vessel.effective_target_duration,
		Time.get_ticks_msec() / 1000.0
	)
	event.ingredient_tags.assign(vessel.ingredient_tags)
	event.source_quality = vessel.source_quality
	event.stir_count = vessel.stir_count
	event.homogeneity = vessel.homogeneity
	event.overheat_duration = vessel.overheat_duration
	process.append_event(event)
	action_recorded.emit(&"heat", process.events.size())
	physical_action_recorded.emit(StringName(RecipeDefinition.FinishMethod.keys()[finish_method].to_lower()))
	_resolve(inventory, finish_method)
	return true


func perform_action(
	actor: Node,
	operation: StringName,
	ingredient_id: StringName,
	ingredient_tags: Array[StringName],
	amount: float,
	temperature: float,
	duration: float,
	required_item_id: StringName = &""
) -> bool:
	if process.events.is_empty():
		active_recipe = _find_recipe(ingredient_id)
	var current_recipe := active_recipe if active_recipe != null else recipe
	if current_recipe == null:
		action_rejected.emit("У станции не назначен рецепт.")
		return false
	var inventory := actor.find_child("InventoryComponent", true, false) as InventoryComponent
	if inventory == null:
		action_rejected.emit("Не найдена сумка игрока.")
		return false
	if required_item_id != &"" and inventory.count(required_item_id) < 1.0:
		var definition := ContentDB.get_definition(required_item_id)
		var item_name := definition.display_name if definition != null else String(required_item_id)
		action_rejected.emit("Нужен ингредиент: %s" % item_name)
		return false
	if process.events.size() >= current_recipe.steps.size():
		reset_process()
		active_recipe = _find_recipe(ingredient_id)
		current_recipe = active_recipe if active_recipe != null else recipe
	var expected_step := current_recipe.steps[process.events.size()]
	if expected_step.operation != operation:
		action_rejected.emit("Сейчас требуется другое действие. Сверься с рецептом.")
		return false
	var consumed_item: ItemInstance
	var actual_tags := ingredient_tags.duplicate()
	if required_item_id != &"":
		consumed_item = inventory.remove_one(required_item_id)
		if consumed_item == null:
			action_rejected.emit("Ингредиент исчез до начала обработки.")
			return false
		var harvested_part := StringName(consumed_item.processing_state.get(&"part", &"whole"))
		actual_tags.append(StringName("part_%s" % harvested_part))
	var event := CookingProcessEvent.new(
		operation,
		ingredient_id,
		amount,
		temperature,
		duration,
		Time.get_ticks_msec() / 1000.0
	)
	event.ingredient_tags = actual_tags
	event.source_quality = consumed_item.quality if consumed_item != null else 1.0
	process.append_event(event)
	action_recorded.emit(operation, process.events.size())
	if process.events.size() == current_recipe.steps.size():
		_resolve(inventory)
	return true


func reset_process() -> void:
	process.clear()
	vessel.reset()
	vessel_state_changed.emit(vessel)
	process_reset.emit()


func to_save_data() -> Dictionary:
	return {
		"process": process.to_save_data(),
		"vessel": vessel.to_save_data(),
		"active_recipe_id": String(active_recipe.id) if active_recipe != null else "",
		"batches_completed": batches_completed,
		"station_tier": station_tier,
	}


func apply_save_data(data: Dictionary) -> void:
	process.apply_save_data(data.get("process", []) as Array)
	vessel.apply_save_data(data.get("vessel", {}) as Dictionary)
	var saved_recipe_id := StringName(data.get("active_recipe_id", ""))
	active_recipe = _find_recipe_by_id(saved_recipe_id)
	if active_recipe == null:
		active_recipe = _find_recipe(vessel.ingredient_id) if vessel.ingredient_id != &"" else recipe
	batches_completed = maxi(0, int(data.get("batches_completed", 0)))
	station_tier = clampi(int(data.get("station_tier", _tier_for_batches(batches_completed))), 0, 3)
	mastery_changed.emit(station_tier, batches_completed)
	vessel_state_changed.emit(vessel)


func _resolve(inventory: InventoryComponent, finish_method: RecipeDefinition.FinishMethod = RecipeDefinition.FinishMethod.BOTTLE) -> void:
	var current_recipe := active_recipe if active_recipe != null else recipe
	var physical_batch := vessel.ingredient_loaded
	var resolved_base := vessel.base_id if vessel.base_id != &"" else current_recipe.required_base_id
	var resolved_turns := vessel.completed_hourglass_turns
	var resolved_finish := finish_method
	var resolved_tier := station_tier
	if not physical_batch:
		# Direct semantic actions are retained for automated fixtures and migration
		# of old saves. Player-facing stations always use the strict physical path.
		resolved_finish = current_recipe.finish_method
		resolved_tier = maxi(station_tier, current_recipe.minimum_station_tier)
		for step: RecipeStepDefinition in current_recipe.steps:
			if step.operation == &"heat":
				resolved_turns = step.minimum_hourglass_turns
				break
	var resolution := RecipeResolver.new().resolve(
		process,
		current_recipe,
		resolved_base,
		resolved_finish,
		resolved_tier,
		resolved_turns
	)
	if not physical_batch:
		resolution.yield_count = current_recipe.base_yield
	var result_definition := ContentDB.get_definition(resolution.result_item_id)
	var result_name := result_definition.display_name if result_definition != null else String(resolution.result_item_id)
	if resolution.quality < RecipeResolution.Quality.WORKING:
		action_rejected.emit("Смесь испорчена. Проверь порядок и признаки процесса.")
		reset_process()
		return
	var result_item := ItemInstance.new(resolution.result_item_id, float(resolution.yield_count))
	result_item.quality = clampf(resolution.score, 0.0, 1.0)
	result_item.processing_state[&"batch_quality"] = RecipeResolution.Quality.keys()[resolution.quality].to_lower()
	result_item.processing_state[&"finish_method"] = RecipeDefinition.FinishMethod.keys()[finish_method].to_lower()
	if not inventory.add_item(result_item):
		action_rejected.emit("В сумке нет места для готового состава.")
		return
	batches_completed += 1
	var previous_tier := station_tier
	station_tier = _tier_for_batches(batches_completed)
	if station_tier != previous_tier:
		physical_action_recorded.emit(&"station_upgrade")
	mastery_changed.emit(station_tier, batches_completed)
	result_created.emit(resolution, result_name)
	reset_process()


func _tier_for_batches(value: int) -> int:
	if value >= 12:
		return 3
	if value >= 5:
		return 2
	if value >= 2:
		return 1
	return 0


func _find_recipe(ingredient_id: StringName) -> RecipeDefinition:
	for candidate: RecipeDefinition in recipes:
		if candidate != null and candidate.primary_ingredient_id == ingredient_id:
			return candidate
	if recipe != null and recipe.primary_ingredient_id == ingredient_id:
		return recipe
	return null


func _find_recipe_by_id(recipe_id: StringName) -> RecipeDefinition:
	if recipe_id == &"":
		return null
	for candidate: RecipeDefinition in recipes:
		if candidate != null and candidate.id == recipe_id:
			return candidate
	if recipe != null and recipe.id == recipe_id:
		return recipe
	return null


func find_recipe_by_id(recipe_id: StringName) -> RecipeDefinition:
	return _find_recipe_by_id(recipe_id)


func add_recipe(value: RecipeDefinition) -> void:
	if value == null or _find_recipe_by_id(value.id) != null:
		return
	recipes.append(value)
