class_name WorldProgressionOrchestrator
extends Node

signal contract_changed(text: String)
signal autosave_requested(reason: StringName)

const RECIPE_PATHS: PackedStringArray = [
	"res://content/recipes/glass_lichen_decoction.tres",
	"res://content/recipes/ashen_bell_tea.tres",
	"res://content/recipes/mirror_reed_broth.tres",
	"res://content/recipes/deep_root_kisel.tres",
	"res://content/recipes/final_concordance.tres",
]

var _phases: WorldPhaseOrchestrator
var _terrain: ExpeditionTerrain
var _cooking: CookingOrchestrator
var _recipes: RecipeKnowledgeOrchestrator
var _loop: GameLoopOrchestrator
var _discovered_mysteries: Dictionary[StringName, bool] = {}
var _session_active: bool = false
var _active_event: WorldMysteryDefinition
var _active_event_instruction: String = ""
var _active_event_progress: float = 0.0
var _active_event_pressure: float = 0.0


func setup(
	phases: WorldPhaseOrchestrator,
	terrain: ExpeditionTerrain,
	cooking: CookingOrchestrator,
	recipes: RecipeKnowledgeOrchestrator,
	loop: GameLoopOrchestrator
) -> void:
	_phases = phases
	_terrain = terrain
	_cooking = cooking
	_recipes = recipes
	_loop = loop
	for path: String in RECIPE_PATHS:
		var recipe := load(path) as RecipeDefinition
		if recipe != null:
			_cooking.add_recipe(recipe)
	terrain.mystery_discovered.connect(_on_mystery_discovered)
	terrain.mystery_event_started.connect(_on_mystery_event_started)
	terrain.mystery_event_failed.connect(_on_mystery_event_failed)
	terrain.mystery_event_progressed.connect(_on_mystery_event_progressed)
	terrain.authored_encounter_completed.connect(_on_authored_encounter_completed)
	cooking.result_created.connect(_on_result_created)
	phases.phase_changed.connect(_on_phase_changed)
	_emit_contract()


func get_contract_text() -> String:
	var phase := _phases.get_current() if _phases != null else null
	if phase == null or phase.content_pack == null:
		return "МИР НЕ ОПРЕДЕЛЁН"
	var pack := phase.content_pack
	var ingredients := PackedStringArray()
	for ingredient_id: StringName in pack.local_ingredient_ids:
		var definition := ContentDB.get_definition(ingredient_id)
		ingredients.append(definition.display_name if definition != null else String(ingredient_id))
	var recipe := _cooking.find_recipe_by_id(pack.transition_recipe_id) if _cooking != null else null
	var next_name := String(pack.next_phase_id)
	for candidate: WorldPhaseDefinition in _phases.get_definitions():
		if candidate.id == pack.next_phase_id:
			next_name = candidate.display_name
			break
	return "%s\nЛокальный образец: %s\nФормула перехода: %s\nСледующий слой: %s" % [
		pack.landscape_statement,
		", ".join(ingredients) if not ingredients.is_empty() else "нет — финальный слой",
		recipe.display_name if recipe != null else "нет",
		next_name if pack.next_phase_id != &"" else "финал",
	]


func activate_session() -> void:
	_session_active = true
	_emit_contract()


func to_save_data() -> Dictionary:
	return {
		"discovered_mysteries": _discovered_mysteries.keys().map(func(value: Variant) -> String: return String(value)),
		"story_phase_id": String(_phases.get_story_phase_id()) if _phases != null else "phase.ordinary",
		"collected_biome_ingredients": _terrain.get_collected_biome_ingredient_spawns() if _terrain != null else [],
		"interactive_world_states": _terrain.get_interactive_world_states() if _terrain != null else {},
	}


func apply_save_data(data: Dictionary) -> void:
	_discovered_mysteries.clear()
	for raw_id: Variant in data.get("discovered_mysteries", []):
		_discovered_mysteries[StringName(raw_id)] = true
	_terrain.apply_discovered_mysteries(data.get("discovered_mysteries", []) as Array)
	_terrain.apply_collected_biome_ingredient_spawns(data.get("collected_biome_ingredients", []) as Array)
	_terrain.apply_interactive_world_states(data.get("interactive_world_states", {}) as Dictionary)
	_phases.set_story_phase(StringName(data.get("story_phase_id", "phase.ordinary")))
	_emit_contract()


func has_discovered(mystery_id: StringName) -> bool:
	return _discovered_mysteries.has(mystery_id)


func simulate_transition_formula() -> bool:
	var phase := _phases.get_current() if _phases != null else null
	if phase == null or phase.content_pack == null or phase.content_pack.next_phase_id == &"":
		return false
	_phases.set_developer_phase(phase.content_pack.next_phase_id)
	return true


func simulate_nearest_mystery_event() -> bool:
	return _terrain != null and _terrain.simulate_nearest_mystery_event()


func _on_mystery_discovered(definition: WorldMysteryDefinition) -> void:
	if definition == null or _discovered_mysteries.has(definition.id):
		return
	_discovered_mysteries[definition.id] = true
	_active_event = null
	_active_event_instruction = ""
	if definition.recipe_hint_id != &"":
		_recipes.discover_recipe(definition.recipe_hint_id)
	if definition.ingredient_hint_id != &"":
		_loop.narrative_notice_requested.emit(definition.display_name, "%s\nИскомый образец: %s" % [definition.discovery_text, _display_name(definition.ingredient_hint_id)])
	else:
		_loop.narrative_notice_requested.emit(definition.display_name, definition.discovery_text)
	autosave_requested.emit(&"world_mystery_discovered")
	_emit_contract()


func _on_authored_encounter_completed(clue_id: StringName, title: String, text: String) -> void:
	_loop.record_trail_clue(clue_id, title, text)


func _on_mystery_event_started(definition: WorldMysteryDefinition, instruction: String) -> void:
	_active_event = definition
	_active_event_instruction = instruction
	_active_event_progress = 0.0
	_active_event_pressure = 0.0
	_loop.narrative_notice_requested.emit("МЕСТО ОТВЕТИЛО", instruction)
	_emit_contract()


func _on_mystery_event_failed(definition: WorldMysteryDefinition, failure_text: String) -> void:
	_active_event = null
	_active_event_instruction = ""
	_active_event_progress = 0.0
	_active_event_pressure = 0.0
	_loop.narrative_notice_requested.emit("КОНТАКТ СОРВАН · %s" % definition.display_name, failure_text)
	_emit_contract()


func _on_mystery_event_progressed(definition: WorldMysteryDefinition, progress: float, pressure: float) -> void:
	if _active_event != definition:
		return
	_active_event_progress = progress
	_active_event_pressure = pressure
	# Update the HUD in coarse steps; the event itself remains smooth in world space.
	if int(progress * 10.0) % 2 == 0:
		_emit_contract()


func _on_phase_changed(definition: WorldPhaseDefinition, developer_override: bool) -> void:
	if not developer_override and definition != null and definition.order > 0:
		var entry_recipe_id := definition.stabilizing_recipe_id
		if entry_recipe_id != &"" and _recipes.is_learned(entry_recipe_id):
			var current_story := _phase_by_id(_phases.get_story_phase_id())
			if current_story == null or definition.order > current_story.order:
				_phases.set_story_phase(definition.id)
				autosave_requested.emit(&"story_world_advanced")
	_emit_contract()


func _on_result_created(_result: RecipeResolution, _display_name: String) -> void:
	var phase := _phases.get_current()
	if phase == null or phase.content_pack == null or _cooking.active_recipe == null:
		return
	if _cooking.active_recipe.id != phase.content_pack.transition_recipe_id:
		return
	_loop.narrative_notice_requested.emit(
		"ПЕРЕХОДНАЯ ФОРМУЛА ГОТОВА",
		"%s стабилизирован. Принятие состава перестроит генерацию в слой «%s»." % [_cooking.active_recipe.display_name, _next_phase_name(phase.content_pack.next_phase_id)]
	)
	autosave_requested.emit(&"transition_formula_brewed")


func _next_phase_name(phase_id: StringName) -> String:
	for definition: WorldPhaseDefinition in _phases.get_definitions():
		if definition.id == phase_id:
			return definition.display_name
	return String(phase_id)


func _phase_by_id(phase_id: StringName) -> WorldPhaseDefinition:
	for definition: WorldPhaseDefinition in _phases.get_definitions():
		if definition.id == phase_id:
			return definition
	return null


func _display_name(definition_id: StringName) -> String:
	var definition := ContentDB.get_definition(definition_id)
	return definition.display_name if definition != null else String(definition_id)


func _emit_contract() -> void:
	contract_changed.emit(get_contract_text())
	if _session_active and _loop != null:
		_loop.set_world_progression_objective(_get_objective_text())


func _get_objective_text() -> String:
	var phase := _phases.get_current() if _phases != null else null
	if phase == null or phase.content_pack == null:
		return ""
	var pack := phase.content_pack
	var world_name := phase.display_name.to_upper()
	if _active_event != null:
		return "%s · %s · настройка %d%% · давление %d%%" % [
			world_name,
			_active_event_instruction,
			int(_active_event_progress * 100.0),
			int(_active_event_pressure * 100.0),
		]
	var mystery := pack.mysteries[0] if not pack.mysteries.is_empty() else null
	if mystery != null and not _discovered_mysteries.has(mystery.id):
		return "%s · найти точку тайны «%s»" % [world_name, mystery.display_name]
	if pack.transition_recipe_id == &"":
		return "%s · исследовать финальную лабораторию и найти брата" % world_name
	var recipe := _cooking.find_recipe_by_id(pack.transition_recipe_id)
	if not _recipes.is_learned(pack.transition_recipe_id):
		var ingredient_name := _display_name(pack.local_ingredient_ids[0]) if not pack.local_ingredient_ids.is_empty() else "локальный образец"
		return "%s · найти %s и проверить формулу «%s»" % [world_name, ingredient_name, recipe.display_name if recipe != null else pack.transition_recipe_id]
	return "%s · принять «%s» и удержать метаморфозу" % [world_name, recipe.display_name if recipe != null else pack.transition_recipe_id]
