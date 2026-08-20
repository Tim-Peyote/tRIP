class_name CookingOrchestrator
extends Node

signal action_recorded(operation: StringName, step_count: int)
signal action_rejected(reason: String)
signal process_reset
signal result_created(result: RecipeResolution, display_name: String)
signal vessel_state_changed(state: ThermalVesselState)
signal physical_action_recorded(action: StringName)

@export var recipe: RecipeDefinition

var process := CookingProcess.new()
var vessel := ThermalVesselState.new()


func _process(delta: float) -> void:
	if vessel.water_amount <= 0.0 and vessel.heat_level == ThermalVesselState.HeatLevel.OFF:
		return
	vessel.simulate(delta)
	vessel_state_changed.emit(vessel)


func add_water() -> bool:
	if not vessel.add_water(1.0):
		action_rejected.emit("В котле уже достаточно воды.")
		return false
	physical_action_recorded.emit(&"add_water")
	vessel_state_changed.emit(vessel)
	return true


func transfer_prepared_ingredient() -> bool:
	if process.events.is_empty() or process.events[0].operation != &"grind":
		action_rejected.emit("Сначала измельчи шляпку в ступке.")
		return false
	var source := process.events[0]
	if not vessel.add_ingredient(source.ingredient_id, source.source_quality):
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


func bottle_result(actor: Node) -> bool:
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
	event.ingredient_tags.assign([&"fungus", &"perception"])
	event.source_quality = vessel.source_quality
	event.stir_count = vessel.stir_count
	event.homogeneity = vessel.homogeneity
	event.overheat_duration = vessel.overheat_duration
	process.append_event(event)
	action_recorded.emit(&"heat", process.events.size())
	_resolve(inventory)
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
	if recipe == null:
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
	if process.events.size() >= recipe.steps.size():
		reset_process()
	var expected_step := recipe.steps[process.events.size()]
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
	if process.events.size() == recipe.steps.size():
		_resolve(inventory)
	return true


func reset_process() -> void:
	process.clear()
	vessel.reset()
	vessel_state_changed.emit(vessel)
	process_reset.emit()


func _resolve(inventory: InventoryComponent) -> void:
	var resolution := RecipeResolver.new().resolve(process, recipe)
	var result_definition := ContentDB.get_definition(resolution.result_item_id)
	var result_name := result_definition.display_name if result_definition != null else String(resolution.result_item_id)
	if resolution.quality < RecipeResolution.Quality.WORKING:
		action_rejected.emit("Смесь испорчена. Проверь порядок и признаки процесса.")
		reset_process()
		return
	if not inventory.add_item(ItemInstance.new(resolution.result_item_id, 1.0)):
		action_rejected.emit("В сумке нет места для готового состава.")
		return
	result_created.emit(resolution, result_name)
	reset_process()
