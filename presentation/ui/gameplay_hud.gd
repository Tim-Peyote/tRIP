class_name GameplayHUD
extends Control

signal resume_requested
signal main_menu_requested
signal overlay_state_changed(is_open: bool)
signal audio_cue_requested(cue_id: StringName)

@onready var prompt_label: Label = $"PromptLabel"
@onready var hold_progress: ProgressBar = $"HoldProgress"
@onready var notice_label: Label = $"NoticeLabel"
@onready var inventory_label: Label = $"InventoryLabel"
@onready var pause_panel: PanelContainer = $"PausePanel"
@onready var notice_timer: Timer = $"NoticeTimer"
@onready var inspection_panel: PanelContainer = $"InspectionPanel"
@onready var inventory_panel: PanelContainer = $"InventoryPanel"
@onready var inventory_scrim: ColorRect = $"InventoryScrim"
@onready var inventory_list: GridContainer = $"InventoryPanel/Margin/Layout/Body/ListScroll/InventoryList"
@onready var inventory_detail_panel: PanelContainer = $"InventoryPanel/Margin/Layout/Body/Detail"
@onready var inventory_detail_category: Label = $"InventoryPanel/Margin/Layout/Body/Detail/DetailMargin/DetailLayout/DetailScroll/DetailContent/InventoryDetailCategory"
@onready var inventory_detail_icon: TextureRect = $"InventoryPanel/Margin/Layout/Body/Detail/DetailMargin/DetailLayout/DetailScroll/DetailContent/InventoryDetailIcon"
@onready var inventory_detail_title: Label = $"InventoryPanel/Margin/Layout/Body/Detail/DetailMargin/DetailLayout/DetailScroll/DetailContent/InventoryDetailTitle"
@onready var inventory_detail_body: Label = $"InventoryPanel/Margin/Layout/Body/Detail/DetailMargin/DetailLayout/DetailScroll/DetailContent/InventoryDetailBody"
@onready var inventory_mass_bar: ProgressBar = $"InventoryPanel/Margin/Layout/CapacityBars/MassCapacity/InventoryMassBar"
@onready var inventory_volume_bar: ProgressBar = $"InventoryPanel/Margin/Layout/CapacityBars/VolumeCapacity/InventoryVolumeBar"
@onready var inventory_capacity_label: Label = $"InventoryPanel/Margin/Layout/InventoryCapacityLabel"
@onready var inventory_mass_caption: Label = $"InventoryPanel/Margin/Layout/CapacityBars/MassCapacity/InventoryMassCaption"
@onready var inventory_volume_caption: Label = $"InventoryPanel/Margin/Layout/CapacityBars/VolumeCapacity/InventoryVolumeCaption"
@onready var inventory_use_button: Button = $"InventoryPanel/Margin/Layout/Body/Detail/DetailMargin/DetailLayout/InventoryActions/InventoryUseButton"
@onready var inventory_drop_button: Button = $"InventoryPanel/Margin/Layout/Body/Detail/DetailMargin/DetailLayout/InventoryActions/InventoryDropButton"
@onready var inventory_sort: OptionButton = $"InventoryPanel/Margin/Layout/FilterBar/InventorySort"
@onready var inventory_item_count: Label = $"InventoryPanel/Margin/Layout/Header/InventoryItemCount"
@onready var inventory_quality_bar: ProgressBar = $"InventoryPanel/Margin/Layout/Body/Detail/DetailMargin/DetailLayout/DetailScroll/DetailContent/InventoryQualityBar"
@onready var inventory_freshness_bar: ProgressBar = $"InventoryPanel/Margin/Layout/Body/Detail/DetailMargin/DetailLayout/DetailScroll/DetailContent/InventoryFreshnessBar"
@onready var inventory_specimen_list: ItemList = $"InventoryPanel/Margin/Layout/Body/Detail/DetailMargin/DetailLayout/DetailScroll/DetailContent/InventorySpecimenList"
@onready var journal_entry_list: ItemList = $"JournalPanel/Margin/Layout/JournalBody/JournalSidebar/JournalEntryList"
@onready var journal_detail_kicker: Label = $"JournalPanel/Margin/Layout/JournalBody/JournalDetail/JournalDetailKicker"
@onready var journal_detail_title: Label = $"JournalPanel/Margin/Layout/JournalBody/JournalDetail/JournalDetailTitle"
@onready var journal_detail_meta: Label = $"JournalPanel/Margin/Layout/JournalBody/JournalDetail/JournalDetailMeta"
@onready var journal_progress: ProgressBar = $"JournalPanel/Margin/Layout/JournalBody/JournalDetail/JournalProgress"
@onready var journal_detail_body: RichTextLabel = $"JournalPanel/Margin/Layout/JournalBody/JournalDetail/JournalDetailScroll/JournalDetailBody"
@onready var journal_counter: Label = $"JournalPanel/Margin/Layout/JournalTabs/JournalCounter"
@onready var inspection_view: SampleInspectionView = $"SampleInspectionView"
@onready var focus_card: PanelContainer = $"FocusCard"
@onready var focus_key: Label = $"FocusCard/Margin/Row/FocusKey"
@onready var focus_title: Label = $"FocusCard/Margin/Row/Text/FocusTitle"
@onready var focus_action: Label = $"FocusCard/Margin/Row/Text/FocusAction"
@onready var pause_settings_panel: SettingsPanel = $"PauseSettingsPanel"

var _player: FirstPersonController
var _cooking: CookingOrchestrator
var _recipe_knowledge: RecipeKnowledgeOrchestrator
var _knowledge: KnowledgeOrchestrator
var _objective: ExpeditionObjectiveOrchestrator
var _clock: ExpeditionClock
var _stealth: StealthOrchestrator
var _hypotheses: HypothesisOrchestrator
var _game_loop: GameLoopOrchestrator
var _persistence: SessionPersistenceOrchestrator
var _spore_tide: SporeTideOrchestrator
var _root_pressure: RootPressureOrchestrator
var _biome_hazard: BiomeHazardOrchestrator
var _inside_root_well: bool = false
var _weather: WeatherOrchestrator
var _vitals: PlayerVitalsComponent
var _notice_tween: Tween
var _notice_rest_y: float
var _last_interaction_context: Dictionary = {}
var _selected_inventory_id: StringName
var _selected_inventory_instance_id: StringName
var _inventory_filter: StringName = &"all"
var _inventory_sort_mode: StringName = &"name"
var _inventory_has_visible_entries: bool = false
var _journal_mode: StringName = &"species"
var _journal_entries: Array[Dictionary] = []
var _selected_journal_id: StringName
var _map_view: ExpeditionMapView


func _ready() -> void:
	if theme == null:
		theme = preload("res://presentation/ui/trip_theme.tres")
	process_mode = Node.PROCESS_MODE_ALWAYS
	$"PausePanel/Margin/Buttons/ResumeButton".pressed.connect(func() -> void: resume_requested.emit())
	$"PausePanel/Margin/Buttons/MainMenuButton".pressed.connect(func() -> void: main_menu_requested.emit())
	$"PausePanel/Margin/Buttons/PauseSettingsButton".pressed.connect(_show_pause_settings)
	pause_settings_panel.closed.connect(_hide_pause_settings)
	$"CycleResultPanel/Margin/Layout/ContinueCycleButton".pressed.connect(_acknowledge_cycle_result)
	inventory_use_button.pressed.connect(_use_selected_inventory_item)
	inventory_drop_button.pressed.connect(_drop_selected_inventory_item)
	(inventory_use_button as InventoryActionButton).inventory_payload_dropped.connect(_on_inventory_payload_dropped)
	(inventory_drop_button as InventoryActionButton).inventory_payload_dropped.connect(_on_inventory_payload_dropped)
	$"InventoryPanel/Margin/Layout/FilterBar/InventoryFilterAll".pressed.connect(_set_inventory_filter.bind(&"all"))
	$"InventoryPanel/Margin/Layout/FilterBar/InventoryFilterIngredients".pressed.connect(_set_inventory_filter.bind(&"ingredients"))
	$"InventoryPanel/Margin/Layout/FilterBar/InventoryFilterConsumables".pressed.connect(_set_inventory_filter.bind(&"consumables"))
	$"InventoryPanel/Margin/Layout/FilterBar/InventoryFilterTools".pressed.connect(_set_inventory_filter.bind(&"tools"))
	inventory_sort.add_item("По названию")
	inventory_sort.add_item("По качеству")
	inventory_sort.add_item("По количеству")
	inventory_sort.add_item("По свежести")
	inventory_sort.item_selected.connect(_set_inventory_sort)
	inventory_specimen_list.item_selected.connect(_on_inventory_specimen_selected)
	journal_entry_list.item_selected.connect(_select_journal_entry)
	$"JournalPanel/Margin/Layout/JournalTabs/JournalTabSpecies".pressed.connect(_set_journal_mode.bind(&"species"))
	$"JournalPanel/Margin/Layout/JournalTabs/JournalTabHypotheses".pressed.connect(_set_journal_mode.bind(&"hypotheses"))
	$"JournalPanel/Margin/Layout/JournalTabs/JournalTabRecipes".pressed.connect(_set_journal_mode.bind(&"recipes"))
	notice_timer.timeout.connect(func() -> void: notice_label.visible = false)
	_notice_rest_y = notice_label.position.y
	for journal_tab: Button in [$"JournalPanel/Margin/Layout/JournalTabs/JournalTabSpecies", $"JournalPanel/Margin/Layout/JournalTabs/JournalTabHypotheses", $"JournalPanel/Margin/Layout/JournalTabs/JournalTabRecipes"]:
		journal_tab.toggle_mode = true
	get_viewport().size_changed.connect(_update_inventory_responsive_layout)
	get_viewport().size_changed.connect(_update_hud_responsive_layout)
	_update_inventory_responsive_layout()
	_update_hud_responsive_layout()
	_refresh_inventory_filter_buttons()
	_map_view = (preload("res://presentation/ui/map_screen.tscn") as PackedScene).instantiate() as ExpeditionMapView
	_map_view.name = "ExpeditionMapView"
	add_child(_map_view)
	_map_view.full_map_changed.connect(_on_full_map_changed)


func setup(player: FirstPersonController) -> void:
	_player = player
	player.interactor.prompt_changed.connect(_on_prompt_changed)
	player.interactor.context_changed.connect(_on_interaction_context_changed)
	player.interactor.hold_progress_changed.connect(_on_hold_progress_changed)
	player.interactor.inspection_requested.connect(_on_inspection_requested)
	player.interactor.inspection_definition_requested.connect(_on_inspection_definition_requested)
	player.inventory.item_added.connect(_on_item_added)
	player.inventory.item_rejected.connect(_on_item_rejected)
	player.inventory.changed.connect(_on_inventory_changed)
	player.inventory.consumable_used.connect(_on_consumable_used)
	player.inventory_requested.connect(_toggle_inventory)
	player.journal_requested.connect(_toggle_journal)
	player.tool_state_changed.connect(_on_tool_state_changed)
	player.distraction_count_changed.connect(_on_distraction_count_changed)
	player.camera_mode_changed.connect(_on_camera_mode_changed)
	inspection_view.closed.connect(_on_inspection_closed)
	visible = true
	set_paused(false)
	player.set_gameplay_enabled(true)
	_update_inventory_label()
	$"ToolLabel".text = player.toolbelt.get_display_name() + "  [Q]"
	_on_distraction_count_changed(player.distraction_thrower.remaining)
	_on_interaction_context_changed({})


func _on_camera_mode_changed(is_third_person: bool) -> void:
	show_notice("КАМЕРА · %s · [V] переключить" % ("ТРЕТЬЕ ЛИЦО" if is_third_person else "ПЕРВОЕ ЛИЦО"))


func setup_vitals(vitals: PlayerVitalsComponent) -> void:
	_vitals = vitals
	vitals.state_changed.connect(_on_vitals_state_changed)
	vitals.condition_changed.connect(_on_vitals_condition_changed)
	vitals.exhausted.connect(func() -> void: show_notice("ИСТОЩЕНИЕ · отдышись или прими подходящую пищу"))
	vitals.damaged.connect(_on_vitals_damaged)
	_on_vitals_state_changed(vitals.get_snapshot())


func setup_weather(weather: WeatherOrchestrator) -> void:
	_weather = weather
	weather.state_changed.connect(_on_weather_state_changed)
	weather.wetness_changed.connect(_on_weather_wetness_changed)
	_on_weather_state_changed(weather.state, weather.get_state_title(), weather.intensity)
	_on_weather_wetness_changed(weather.wetness)


func setup_map(exploration: MapExplorationOrchestrator, terrain: ExpeditionTerrain, phases: WorldPhaseOrchestrator) -> void:
	_map_view.setup(exploration, terrain, _player, phases)


func setup_cooking(cooking: CookingOrchestrator) -> void:
	_cooking = cooking
	cooking.action_recorded.connect(_on_cooking_action_recorded)
	cooking.action_rejected.connect(show_notice)
	cooking.process_warning.connect(show_notice)
	cooking.result_created.connect(_on_cooking_result_created)
	cooking.vessel_state_changed.connect(_on_vessel_state_changed)
	cooking.physical_action_recorded.connect(_on_physical_cooking_action)
	_on_vessel_state_changed(cooking.vessel)


func setup_recipe_knowledge(recipe_knowledge: RecipeKnowledgeOrchestrator) -> void:
	_recipe_knowledge = recipe_knowledge
	recipe_knowledge.recipe_learned.connect(_on_recipe_learned)
	recipe_knowledge.recipe_observation_added.connect(_on_recipe_observation_added)
	_update_journal()


func setup_knowledge(knowledge: KnowledgeOrchestrator) -> void:
	_knowledge = knowledge
	knowledge.entry_changed.connect(_on_knowledge_changed)
	inspection_view.clue_found.connect(knowledge.record_clue)
	inspection_view.inspection_completed.connect(knowledge.understand)
	_update_journal()


func setup_objective(objective: ExpeditionObjectiveOrchestrator) -> void:
	_objective = objective
	objective.objective_updated.connect(_on_objective_updated)
	objective.notice_requested.connect(show_notice)
	_on_objective_updated(objective.get_objective_text())


func setup_clock(clock: ExpeditionClock) -> void:
	_clock = clock
	clock.time_changed.connect(_on_clock_changed)
	_on_clock_changed(clock.progress)


func setup_stealth(stealth: StealthOrchestrator) -> void:
	_stealth = stealth
	stealth.threat_changed.connect(_on_threat_changed)
	_on_threat_changed(stealth.get_threat(), "СКРЫТ")


func setup_hypotheses(hypotheses: HypothesisOrchestrator) -> void:
	_hypotheses = hypotheses
	hypotheses.hypothesis_updated.connect(_on_hypothesis_updated)
	_update_journal()


func setup_game_loop(game_loop: GameLoopOrchestrator) -> void:
	_game_loop = game_loop
	game_loop.stage_changed.connect(_on_loop_stage_changed)
	game_loop.result_ready.connect(_on_cycle_result_ready)
	game_loop.narrative_notice_requested.connect(_on_narrative_notice_requested)
	_on_loop_stage_changed(game_loop.stage, game_loop.get_objective_text())


func setup_persistence(persistence: SessionPersistenceOrchestrator) -> void:
	_persistence = persistence
	persistence.saved.connect(_on_session_saved)


func setup_spore_tide(spore_tide: SporeTideOrchestrator) -> void:
	_spore_tide = spore_tide
	spore_tide.state_changed.connect(_on_spore_tide_state_changed)
	spore_tide.exposure_changed.connect(_on_spore_exposure_changed)
	spore_tide.shelter_changed.connect(_on_spore_shelter_changed)
	spore_tide.overwhelmed.connect(func() -> void: show_notice("Споры забили дыхание. Роща вытолкнула тебя ко входу."))


func setup_root_pressure(root_pressure: RootPressureOrchestrator) -> void:
	_root_pressure = root_pressure
	root_pressure.state_changed.connect(_on_root_pressure_state_changed)
	root_pressure.pressure_changed.connect(_on_root_pressure_changed)
	root_pressure.ward_changed.connect(_on_root_ward_changed)
	root_pressure.area_changed.connect(_on_root_area_changed)
	root_pressure.overwhelmed.connect(func() -> void: show_notice("Корни нашли твой ритм и вытолкнули ко входу в колодец."))


func setup_biome_hazard(hazard: BiomeHazardOrchestrator) -> void:
	_biome_hazard = hazard
	hazard.state_changed.connect(_on_biome_hazard_state_changed)
	hazard.exposure_changed.connect(_on_biome_hazard_exposure_changed)
	_on_biome_hazard_state_changed(hazard.state, "", "")
	_on_biome_hazard_exposure_changed(hazard.exposure)


func clear() -> void:
	if _map_view != null:
		_map_view.set_full_map_open(false)
	_player = null
	_cooking = null
	_knowledge = null
	_objective = null
	_clock = null
	_stealth = null
	_hypotheses = null
	_game_loop = null
	_persistence = null
	_spore_tide = null
	_root_pressure = null
	_biome_hazard = null
	_weather = null
	_inside_root_well = false
	prompt_label.text = ""
	focus_card.visible = false
	hold_progress.visible = false
	notice_label.visible = false
	inspection_panel.visible = false
	inspection_view.visible = false
	inventory_panel.visible = false
	$"JournalPanel".visible = false
	$"CycleResultPanel".visible = false
	visible = false


func set_paused(is_paused: bool) -> void:
	if is_paused:
		close_top_overlay()
	$"PauseScrim".visible = is_paused
	pause_panel.visible = is_paused
	if not is_paused:
		pause_settings_panel.visible = false
	if _player != null:
		_player.set_viewmodel_interface_hidden(is_paused)
	if is_paused:
		$"PausePanel/Margin/Buttons/ResumeButton".grab_focus()


func is_pause_settings_visible() -> bool:
	return pause_settings_panel.visible


func close_pause_settings() -> bool:
	if not pause_settings_panel.visible:
		return false
	_hide_pause_settings()
	return true


func _show_pause_settings() -> void:
	pause_panel.visible = false
	pause_settings_panel.visible = true
	pause_settings_panel.focus_first_control()


func _hide_pause_settings() -> void:
	pause_settings_panel.visible = false
	pause_panel.visible = true
	$"PausePanel/Margin/Buttons/PauseSettingsButton".grab_focus()


func _on_prompt_changed(text: String) -> void:
	prompt_label.text = text


func _on_interaction_context_changed(context: Dictionary) -> void:
	_last_interaction_context = context
	var available := not context.is_empty()
	focus_card.visible = available
	prompt_label.visible = false
	if not available:
		return
	focus_key.text = String(context.get("key", "E"))
	focus_title.text = String(context.get("title", "ОБЪЕКТ")).to_upper()
	focus_action.text = String(context.get("action", context.get("prompt", "Взаимодействовать")))
	var physical := bool(context.get("physical", false))
	var accent := TripUITheme.EMBER if physical else TripUITheme.MOSS
	focus_card.add_theme_stylebox_override("panel", TripUITheme.make_glass_panel(accent))
	focus_key.modulate = accent


func _on_hold_progress_changed(progress: float) -> void:
	hold_progress.value = progress * 100.0
	hold_progress.visible = progress > 0.0


func _on_item_added(item: ItemInstance, display_name: String) -> void:
	audio_cue_requested.emit(&"pickup")
	var part := String(item.processing_state.get(&"part", ""))
	var quality := ""
	if not part.is_empty():
		quality = " · %s · качество %d%%" % [part, roundi(item.quality * 100.0)]
	show_notice("В сумке: %s%s" % [display_name, quality])
	_update_inventory_label()


func _on_item_rejected(_definition_id: StringName, reason: String) -> void:
	var messages := {
		"metabolic_limit": "Организм уже удерживает три разных состава. Дождись ослабления одного из них.",
		"mass_limit": "Слишком тяжело для текущей нагрузки.",
		"volume_limit": "В сумке не осталось свободного объёма.",
	}
	show_notice(String(messages.get(reason, "Не помещается: %s" % reason)))


func _on_inventory_changed() -> void:
	_update_inventory_label()
	_update_inventory_panel()


func _on_consumable_used(_effect_ids: Array[StringName], display_name: String) -> void:
	show_notice("Принято: %s" % display_name)


func _on_cooking_action_recorded(operation: StringName, step_count: int) -> void:
	var verbs: Dictionary = {
		&"wash": "Образец промыт",
		&"slice": "Образец разделён",
		&"grind": "Образец измельчён и готов к переносу",
		&"heat": "Смесь выдержана на слабом огне",
	}
	show_notice("%s  ·  этап %d" % [verbs.get(operation, String(operation)), step_count])


func _on_cooking_result_created(result: RecipeResolution, display_name: String) -> void:
	var quality_names := ["испорчено", "нестабильно", "рабочее", "чистое", "открытие"]
	show_notice("Готово: %s ×%d · %s · [1] применить" % [display_name, result.yield_count, quality_names[result.quality]])


func _on_vessel_state_changed(state: ThermalVesselState) -> void:
	$"CookingStatusLabel".text = state.get_stage_text()
	$"CookingStatusLabel".visible = state.water_amount > 0.0 or state.heat_level != ThermalVesselState.HeatLevel.OFF


func _on_physical_cooking_action(action: StringName) -> void:
	var messages: Dictionary = {
		&"add_water": "В котёл налита холодная вода",
		&"add_kvass": "Основа: кислый зерновой квас",
		&"add_spirit": "Основа: хлебный спирт — держи вдали от бурного огня",
		&"transfer": "Измельчённая шляпка добавлена в воду",
		&"heat_0": "Очаг погашен",
		&"heat_1": "Слабый огонь",
		&"heat_2": "Сильный огонь — следи за температурой",
		&"stir": "Состав перемешан",
		&"bellows": "Мехи усилили жар — наблюдай за пузырями",
		&"hourglass": "Песочные часы перевёрнуты · один оборот 8 секунд",
		&"lower_vessel": "Котёл опущен к огню",
		&"raise_vessel": "Котёл снят с прямого жара",
		&"station_upgrade": "ПОЛЕВАЯ ЛАБОРАТОРИЯ УЛУЧШЕНА · открыта новая точность",
		&"discard": "Состав вылит · рабочее место очищено",
	}
	if messages.has(action):
		show_notice(messages[action])


func _on_tool_state_changed(display_name: String, _is_equipped: bool) -> void:
	$"ToolLabel".text = display_name + "  [Q]"
	show_notice(display_name)


func _toggle_inventory() -> void:
	var should_open := not inventory_panel.visible
	_close_field_panels()
	inventory_panel.visible = should_open
	inventory_scrim.visible = should_open
	audio_cue_requested.emit(&"open" if should_open else &"close")
	_update_inventory_panel()
	_apply_field_overlay_state()
	if should_open:
		_animate_inventory_open()
		var first_button := _first_inventory_button()
		if first_button != null:
			first_button.grab_focus()


func _toggle_journal() -> void:
	var should_open: bool = not bool($"JournalPanel".visible)
	_close_field_panels()
	$"JournalPanel".visible = should_open
	audio_cue_requested.emit(&"open" if should_open else &"close")
	_update_journal()
	_apply_field_overlay_state()


func _toggle_map() -> void:
	var should_open := not _map_view.is_full_map_open()
	_close_field_panels()
	_map_view.set_full_map_open(should_open)
	audio_cue_requested.emit(&"open" if should_open else &"close")
	_apply_field_overlay_state()


func _on_full_map_changed(_is_open: bool) -> void:
	_apply_field_overlay_state()


func _on_knowledge_changed(_definition_id: StringName, _level: int) -> void:
	_update_journal()
	show_notice("Гербарий обновлён · [J]")


func _on_hypothesis_updated(_hypothesis_id: StringName, is_verified: bool) -> void:
	_update_journal()
	if is_verified:
		show_notice("Гипотеза подтверждена · новый рецепт обоснован")


func _on_recipe_learned(_recipe_id: StringName, display_name: String) -> void:
	_update_journal()
	show_notice("ФОРМУЛА ЗАПИСАНА · %s" % display_name.to_upper())


func _on_objective_updated(text: String) -> void:
	$"ObjectiveLabel".text = text


func _on_loop_stage_changed(_stage: int, objective_text: String) -> void:
	$"ObjectiveLabel".text = objective_text


func _on_narrative_notice_requested(title: String, text: String) -> void:
	show_notice("%s · %s" % [title, text])


func _on_cycle_result_ready(summary: Dictionary) -> void:
	$"CycleResultPanel/Margin/Layout/CycleResultTitle".text = String(summary.get("title", "ЦИКЛ ЗАВЕРШЁН"))
	$"CycleResultPanel/Margin/Layout/CycleResultBody".text = "Качество состава: %s\nТочность процесса: %d%%\nВремя вылазки: %02d:%02d\nИзучено признаков: %d\n\nНАГРАДА\n%s" % [
		String(summary.get("quality", "—")),
		int(summary.get("score", 0)),
		int(summary.get("expedition_seconds", 0)) / 60,
		int(summary.get("expedition_seconds", 0)) % 60,
		int(summary.get("knowledge", 0)),
		String(summary.get("reward", "—")),
	]
	$"CycleResultPanel".visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$"CycleResultPanel/Margin/Layout/ContinueCycleButton".grab_focus()


func _acknowledge_cycle_result() -> void:
	$"CycleResultPanel".visible = false
	if _game_loop != null:
		_game_loop.acknowledge_reward()
	if _player != null:
		_player.capture_mouse()


func _on_session_saved(_slot_id: int, _reason: StringName) -> void:
	$"SaveIndicator".visible = true
	$"SaveIndicatorTimer".start()


func _on_clock_changed(_progress: float) -> void:
	if _clock != null:
		$"ClockLabel".text = _clock.get_display_text()


func _on_threat_changed(value: float, state_text: String) -> void:
	$"ThreatBar".value = value * 100.0
	$"ThreatBar".visible = value > 0.01
	$"ThreatLabel".text = state_text
	$"ThreatLabel".modulate = Color(0.9, 0.32, 0.2) if value >= 0.55 else Color(0.68, 0.76, 0.54)


func _on_distraction_count_changed(remaining: int) -> void:
	$"DistractionLabel".text = "КАМНИ  %d  [G]" % remaining


func _on_spore_tide_state_changed(state: int, label: String) -> void:
	$"SporeTideLabel".text = label
	$"SporeTideLabel".visible = state != SporeTideOrchestrator.State.CALM


func _on_spore_exposure_changed(value: float) -> void:
	$"SporeTideBar".value = value * 100.0
	$"SporeTideBar".visible = value > 0.01


func _on_spore_shelter_changed(is_sheltered: bool, shelter_name: String) -> void:
	$"SporeShelterLabel".visible = is_sheltered
	$"SporeShelterLabel".text = "УКРЫТИЕ · %s" % shelter_name.to_upper()


func _on_root_area_changed(is_inside: bool) -> void:
	_inside_root_well = is_inside
	$"RootPressureLabel".visible = is_inside
	$"RootPressureBar".visible = is_inside
	if not is_inside:
		$"RootWardLabel".visible = false


func _on_root_pressure_state_changed(_state: int, label: String) -> void:
	$"RootPressureLabel".text = label
	$"RootPressureLabel".visible = _inside_root_well


func _on_root_pressure_changed(value: float) -> void:
	$"RootPressureBar".value = value * 100.0
	$"RootPressureBar".visible = _inside_root_well


func _on_root_ward_changed(is_warded: bool, ward_name: String) -> void:
	$"RootWardLabel".visible = _inside_root_well and is_warded
	$"RootWardLabel".text = "МЕМБРАНА · %s" % ward_name.to_upper()


func _on_biome_hazard_state_changed(state: int, title: String, instruction: String) -> void:
	$"BiomeHazardLabel".visible = state != BiomeHazardOrchestrator.State.CALM
	$"BiomeHazardInstruction".visible = state != BiomeHazardOrchestrator.State.CALM
	$"BiomeHazardLabel".text = title
	$"BiomeHazardInstruction".text = instruction
	$"BiomeHazardLabel".modulate = Color(0.96, 0.74, 0.28) if state == BiomeHazardOrchestrator.State.WARNING else Color(0.98, 0.32, 0.22)


func _on_biome_hazard_exposure_changed(value: float) -> void:
	$"BiomeHazardBar".value = value * 100.0
	$"BiomeHazardBar".visible = value > 0.01


func _on_inspection_requested(title: String, description: String) -> void:
	$"InspectionPanel/Margin/Text/InspectionTitle".text = title
	$"InspectionPanel/Margin/Text/InspectionDescription".text = description
	inspection_panel.visible = not inspection_panel.visible
	audio_cue_requested.emit(&"open" if inspection_panel.visible else &"close")


func _on_inspection_definition_requested(definition_id: StringName, title: String, description: String) -> void:
	_close_field_panels()
	if not inspection_view.open_definition(definition_id):
		_on_inspection_requested(title, description)
		return
	inspection_panel.visible = false
	audio_cue_requested.emit(&"open")
	_player.interactor.set_process(false)
	_player.set_gameplay_enabled(false)
	_player.set_viewmodel_interface_hidden(true)
	prompt_label.visible = false
	overlay_state_changed.emit(true)


func _on_inspection_closed() -> void:
	if _player == null:
		return
	_player.interactor.set_process(true)
	_player.set_gameplay_enabled(true)
	_player.set_viewmodel_interface_hidden(false)
	_player.capture_mouse()
	focus_card.visible = not _last_interaction_context.is_empty()
	overlay_state_changed.emit(false)


func has_modal_overlay() -> bool:
	return inventory_panel.visible or $"JournalPanel".visible or inspection_view.visible or _map_view.is_full_map_open()


func close_top_overlay() -> bool:
	if inspection_view.visible:
		inspection_view.close()
		return true
	if inventory_panel.visible or $"JournalPanel".visible:
		_close_field_panels()
		_apply_field_overlay_state()
		return true
	if _map_view.is_full_map_open():
		_map_view.set_full_map_open(false)
		return true
	return false


func _close_field_panels() -> void:
	inventory_panel.visible = false
	inventory_scrim.visible = false
	$"JournalPanel".visible = false
	if _map_view != null:
		_map_view.set_full_map_open(false)


func _apply_field_overlay_state() -> void:
	var is_open: bool = inventory_panel.visible or bool($"JournalPanel".visible) or (_map_view != null and _map_view.is_full_map_open())
	if _map_view != null:
		_map_view.set_minimap_suppressed(is_open and not _map_view.is_full_map_open())
	if _player != null:
		_player.interactor.set_process(not is_open)
		_player.set_gameplay_enabled(not is_open)
		_player.set_viewmodel_interface_hidden(is_open)
		if is_open:
			_player.release_mouse()
		else:
			_player.capture_mouse()
	focus_card.visible = not is_open and not _last_interaction_context.is_empty()
	overlay_state_changed.emit(is_open)


func show_notice(text: String) -> void:
	notice_label.text = text
	notice_label.visible = true
	notice_label.modulate.a = 0.0
	if _notice_tween != null and _notice_tween.is_valid():
		_notice_tween.kill()
	notice_label.position.y = _notice_rest_y + 8.0
	_notice_tween = create_tween().set_parallel(true)
	_notice_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_notice_tween.tween_property(notice_label, "modulate:a", 1.0, 0.2)
	_notice_tween.tween_property(notice_label, "position:y", _notice_rest_y, 0.24)
	notice_timer.start()


func _on_weather_state_changed(_state: int, title: String, value: float) -> void:
	$"WeatherLabel".text = title.to_upper()
	$"WeatherLabel".visible = _state != WeatherOrchestrator.State.CLEAR or value > 0.05


func _on_weather_wetness_changed(value: float) -> void:
	$"WeatherBar".value = value * 100.0
	$"WeatherBar".visible = value > 0.04


func _on_vitals_state_changed(snapshot: Dictionary) -> void:
	var health := float(snapshot.get("health", 0.0))
	var maximum_health := maxf(1.0, float(snapshot.get("maximum_health", 1.0)))
	var stamina := float(snapshot.get("stamina", 0.0))
	var maximum_stamina := maxf(1.0, float(snapshot.get("maximum_stamina", 1.0)))
	$"VitalsPanel/Margin/Layout/HealthBar".value = health / maximum_health * 100.0
	$"VitalsPanel/Margin/Layout/StaminaBar".value = stamina / maximum_stamina * 100.0
	$"VitalsPanel/Margin/Layout/Top/HealthLabel".text = "ЗДОРОВЬЕ  %d / %d" % [ceili(health), ceili(maximum_health)]
	$"VitalsPanel/Margin/Layout/StaminaLabel".text = "ВЫНОСЛИВОСТЬ  %d / %d" % [ceili(stamina), ceili(maximum_stamina)]
	var temperature := float(snapshot.get("core_temperature", 36.7))
	var wet := float(snapshot.get("wetness", 0.0))
	var spores := float(snapshot.get("spore_load", 0.0))
	var toxicity_value := float(snapshot.get("toxicity", 0.0))
	$"VitalsPanel/Margin/Layout/PhysiologyLabel".text = "ТЕЛО %.1f°C  ·  ВЛАГА %d%%  ·  СПОРЫ %d%%  ·  ТОКСИНЫ %d%%" % [temperature, roundi(wet * 100.0), roundi(spores * 100.0), roundi(toxicity_value * 100.0)]
	var slot_labels := PackedStringArray()
	for slot: Dictionary in snapshot.get("food_slots", []):
		var seconds := maxi(0, roundi(float(slot.get("remaining", 0.0))))
		slot_labels.append("● %s  %d:%02d" % [String(slot.get("name", "СОСТАВ")).to_upper(), seconds / 60, seconds % 60])
	while slot_labels.size() < PlayerVitalsComponent.MAX_FOOD_SLOTS:
		slot_labels.append("○ ПУСТО")
	$"VitalsPanel/Margin/Layout/FoodSlotsLabel".text = "   ".join(slot_labels)
	var condition := StringName(snapshot.get("condition", &"normal"))
	var has_food := not (snapshot.get("food_slots", []) as Array).is_empty()
	$"VitalsPanel/Margin/Layout/PhysiologyLabel".visible = condition != &"normal" or wet > 0.04 or spores > 0.04 or toxicity_value > 0.04
	$"VitalsPanel/Margin/Layout/FoodSlotsLabel".visible = has_food
	_update_vitals_compact_height($"VitalsPanel/Margin/Layout/PhysiologyLabel".visible, has_food)
	$"VitalsPanel".visible = true


func _on_vitals_condition_changed(_condition_id: StringName, title: String) -> void:
	$"VitalsPanel/Margin/Layout/Top/ConditionLabel".text = title


func _on_vitals_damaged(amount: float, source: StringName) -> void:
	if amount >= 1.0:
		show_notice("УРОН %d · %s" % [ceili(amount), String(source).to_upper()])


func _make_vitals_fill(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style


func _update_inventory_label() -> void:
	if _player == null:
		inventory_label.text = ""
		return
	inventory_label.text = "СУМКА  %.1f/%.1f л  ·  %.1f/%.1f кг  [I]" % [
		_player.inventory.current_volume(), _player.inventory.maximum_volume,
		_player.inventory.current_mass(), _player.inventory.maximum_mass,
	]


func _update_inventory_panel() -> void:
	if _player == null:
		_clear_inventory_list()
		return
	_clear_inventory_list()
	var catalog := _player.inventory.get_catalog(_inventory_sort_mode)
	var visible_entries: Array[Dictionary] = []
	var total_units := 0.0
	for stack: Dictionary in catalog:
		var definition_id: StringName = stack["definition_id"]
		var definition := ContentDB.get_definition(definition_id)
		if not _inventory_definition_matches_filter(definition):
			continue
		visible_entries.append(stack)
		total_units += float(stack["quantity"])
		var accent := _inventory_category_color(definition)
		var card := (preload("res://presentation/ui/inventory_item_card.tscn") as PackedScene).instantiate() as VBoxContainer
		card.set_meta(&"definition_id", definition_id)
		var button := card.get_node("Button") as InventoryDragButton
		button.toggle_mode = true
		button.button_pressed = definition_id == _selected_inventory_id
		button.set_meta(&"definition_id", definition_id)
		button.text = ""
		button.icon = _inventory_icon(definition)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		if button.icon != null:
			button.expand_icon = true
		else:
			button.text = _inventory_fallback_glyph(definition)
			button.add_theme_font_size_override("font_size", 34)
		button.add_theme_stylebox_override("normal", TripUITheme.make_inventory_slot(&"normal", accent))
		button.add_theme_stylebox_override("hover", TripUITheme.make_inventory_slot(&"hover", accent))
		button.add_theme_stylebox_override("focus", TripUITheme.make_inventory_slot(&"selected", accent))
		button.add_theme_stylebox_override("pressed", TripUITheme.make_inventory_slot(&"pressed", accent))
		button.add_theme_stylebox_override("hover_pressed", TripUITheme.make_inventory_slot(&"selected", accent))
		button.tooltip_text = definition.description if definition != null else String(definition_id)
		var specimens := _player.inventory.get_specimens(definition_id)
		var instance_id := specimens[0].instance_id if not specimens.is_empty() else &""
		button.configure_drag({
			"kind": &"inventory_item",
			"definition_id": definition_id,
			"instance_id": instance_id,
			"consumable": definition is ConsumableDefinition,
		}, button.icon, definition.display_name if definition != null else String(definition_id))
		button.pressed.connect(_select_inventory_stack.bind(definition_id))
		button.focus_entered.connect(_select_inventory_stack.bind(definition_id, false))
		button.mouse_entered.connect(_select_inventory_stack.bind(definition_id, false))
		var name_label := card.get_node("Name") as Label
		name_label.text = definition.display_name if definition != null else String(definition_id)
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var meta_label := card.get_node("Metadata") as Label
		meta_label.text = "×%.0f   ·   %d%%" % [float(stack["quantity"]), roundi(float(stack["best_quality"]) * 100.0)]
		meta_label.add_theme_font_size_override("font_size", 12)
		meta_label.add_theme_color_override("font_color", accent)
		meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inventory_list.add_child(card)
	_inventory_has_visible_entries = not visible_entries.is_empty()
	inventory_item_count.text = "%d ВИДОВ  ·  %.0f ПРЕДМЕТОВ" % [visible_entries.size(), total_units]
	if inventory_list.get_child_count() == 0:
		inventory_list.add_child(_make_inventory_empty_state())
		if catalog.is_empty():
			_selected_inventory_id = &""
			_selected_inventory_instance_id = &""
		_show_empty_inventory_detail()
	elif _selected_inventory_id == &"" or _player.inventory.count(_selected_inventory_id) <= 0.0 or not _inventory_definition_matches_filter(ContentDB.get_definition(_selected_inventory_id)):
		_select_inventory_stack(visible_entries[0]["definition_id"], false)
	else:
		_select_inventory_stack(_selected_inventory_id, false)
	inventory_mass_bar.max_value = _player.inventory.maximum_mass
	inventory_mass_bar.value = _player.inventory.current_mass()
	inventory_volume_bar.max_value = _player.inventory.maximum_volume
	inventory_volume_bar.value = _player.inventory.current_volume()
	inventory_capacity_label.text = "НАГРУЗКА  %.1f / %.1f кг     ·     ОБЪЁМ  %.1f / %.1f л" % [
		_player.inventory.current_mass(), _player.inventory.maximum_mass,
		_player.inventory.current_volume(), _player.inventory.maximum_volume,
	]
	inventory_mass_caption.text = "ВЕС  %.1f / %.1f КГ" % [_player.inventory.current_mass(), _player.inventory.maximum_mass]
	inventory_volume_caption.text = "ОБЪЁМ  %.1f / %.1f Л" % [_player.inventory.current_volume(), _player.inventory.maximum_volume]
	_update_inventory_responsive_layout()


func _make_inventory_empty_state() -> Control:
	var panel := (preload("res://presentation/ui/inventory_empty_state.tscn") as PackedScene).instantiate() as Control
	if not _player.inventory.items.is_empty():
		panel.get_node("Center/Content/Title").text = "В ЭТОМ РАЗДЕЛЕ ПУСТО"
		panel.get_node("Center/Content/Body").text = "Смени категорию или продолжай искать подходящие предметы в мире."
	return panel


func _update_inventory_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var window_size := Vector2(DisplayServer.window_get_size())
	var physical_scale := maxf(1.0, minf(window_size.x / maxf(viewport_size.x, 1.0), window_size.y / maxf(viewport_size.y, 1.0)))
	# canvas_items keeps a 1280×720 logical UI at every resolution. Cap the
	# satchel in physical pixels as well, otherwise 1440p/4K turns it into an
	# enormous wall of black despite sensible logical anchors.
	var target_width := minf(viewport_size.x - 40.0, minf(window_size.x - 48.0, 1840.0) / physical_scale)
	var target_height := minf(viewport_size.y - 32.0, minf(window_size.y - 48.0, 1080.0) / physical_scale)
	var half_width := maxf(300.0, target_width * 0.5)
	var half_height := maxf(220.0, target_height * 0.5)
	inventory_panel.anchor_left = 0.5
	inventory_panel.anchor_top = 0.5
	inventory_panel.anchor_right = 0.5
	inventory_panel.anchor_bottom = 0.5
	inventory_panel.offset_left = -half_width
	inventory_panel.offset_right = half_width
	inventory_panel.offset_top = -half_height
	inventory_panel.offset_bottom = half_height
	var available_width := half_width * 2.0
	var list_scroll := $InventoryPanel/Margin/Layout/Body/ListScroll as ScrollContainer
	var body := $InventoryPanel/Margin/Layout/Body as HBoxContainer
	inventory_sort.visible = available_width >= 880.0 and _inventory_has_visible_entries
	if not _inventory_has_visible_entries:
		inventory_list.columns = 1
		list_scroll.custom_minimum_size.x = 0.0
		body.add_theme_constant_override("separation", 0)
		inventory_detail_panel.visible = false
	elif available_width >= 1160.0:
		inventory_list.columns = 5
		list_scroll.custom_minimum_size.x = 690.0
		inventory_detail_panel.custom_minimum_size.x = 320.0
		body.add_theme_constant_override("separation", 22)
		inventory_detail_panel.visible = true
	elif available_width >= 880.0:
		inventory_list.columns = 3
		list_scroll.custom_minimum_size.x = 450.0
		inventory_detail_panel.custom_minimum_size.x = 286.0
		body.add_theme_constant_override("separation", 18)
		inventory_detail_panel.visible = true
	elif available_width >= 720.0:
		inventory_list.columns = 2
		list_scroll.custom_minimum_size.x = 306.0
		inventory_detail_panel.custom_minimum_size.x = 250.0
		body.add_theme_constant_override("separation", 14)
		inventory_detail_panel.visible = true
	else:
		inventory_list.columns = 3
		list_scroll.custom_minimum_size.x = 0.0
		body.add_theme_constant_override("separation", 0)
		inventory_detail_panel.visible = false


func _update_hud_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var safe_x := clampf(viewport_size.x * 0.019, 16.0, 34.0)
	$"ObjectiveLabel".offset_left = safe_x
	$"ObjectiveLabel".offset_right = minf(viewport_size.x * 0.48, safe_x + 520.0)
	$"ClockLabel".offset_left = -minf(190.0, viewport_size.x * 0.26)
	$"ClockLabel".offset_right = -safe_x
	$"InventoryLabel".offset_left = safe_x
	$"ToolLabel".offset_right = -safe_x
	$"DistractionLabel".offset_right = -safe_x
	$"VitalsPanel".offset_left = safe_x
	$"VitalsPanel".offset_right = safe_x + clampf(viewport_size.x * 0.27, 300.0, 350.0)
	var inventory_margin := clampf(viewport_size.x * 0.022, 20.0, 30.0)
	var inventory_margin_node := $InventoryPanel/Margin as MarginContainer
	for side: StringName in [&"margin_left", &"margin_right"]:
		inventory_margin_node.add_theme_constant_override(side, roundi(inventory_margin))
	var journal := $"JournalPanel" as PanelContainer
	var journal_half_width := minf(540.0, maxf(300.0, (viewport_size.x - 48.0) * 0.5))
	var journal_half_height := minf(310.0, maxf(220.0, (viewport_size.y - 48.0) * 0.5))
	journal.offset_left = -journal_half_width
	journal.offset_right = journal_half_width
	journal.offset_top = -journal_half_height
	journal.offset_bottom = journal_half_height


func _update_vitals_compact_height(show_physiology: bool, show_food: bool) -> void:
	var height := 57.0
	if show_physiology:
		height += 14.0
	if show_food:
		height += 14.0
	$"VitalsPanel".offset_bottom = -68.0
	$"VitalsPanel".offset_top = $"VitalsPanel".offset_bottom - height


func _show_empty_inventory_detail() -> void:
	inventory_detail_category.text = "ДОРОЖНЫЙ КОМПЛЕКТ"
	inventory_detail_category.modulate = Color("9eb4a0")
	inventory_detail_icon.texture = null
	inventory_detail_title.text = "Готов к вылазке"
	inventory_detail_body.text = "Здесь появятся свойства выбранного образца, его происхождение и доступные действия."
	inventory_quality_bar.value = 0.0
	inventory_freshness_bar.value = 0.0
	inventory_specimen_list.clear()
	inventory_specimen_list.add_item("Нет собранных образцов")
	inventory_use_button.disabled = true
	inventory_use_button.text = "Сначала найди сырьё"
	inventory_drop_button.disabled = true
	inventory_drop_button.text = "Нечего выкладывать"


func _clear_inventory_list() -> void:
	for child: Node in inventory_list.get_children():
		inventory_list.remove_child(child)
		child.queue_free()


func _select_inventory_stack(definition_id: StringName, play_audio: bool = true) -> void:
	if play_audio:
		audio_cue_requested.emit(&"select")
	_selected_inventory_id = definition_id
	_selected_inventory_instance_id = &""
	var definition := ContentDB.get_definition(definition_id)
	if definition == null:
		inventory_detail_title.text = String(definition_id)
		inventory_detail_body.text = "Нет данных об образце."
		inventory_use_button.disabled = true
		inventory_drop_button.disabled = true
		return
	for child: Node in inventory_list.get_children():
		var button := child.get_child(0) as Button if child.get_child_count() > 0 else null
		if button != null:
			button.button_pressed = StringName(button.get_meta(&"definition_id", &"")) == definition_id
	var category := _inventory_category_title(definition)
	inventory_detail_category.text = category
	inventory_detail_category.modulate = _inventory_category_color(definition)
	inventory_detail_icon.texture = _inventory_icon(definition)
	var unit_mass: float = float(definition.unit_mass) if definition is IngredientDefinition else (float(definition.mass) if definition is ItemDefinition else 0.0)
	var unit_volume: float = float(definition.unit_volume) if definition is IngredientDefinition else (float(definition.volume) if definition is ItemDefinition else 0.0)
	inventory_detail_title.text = definition.display_name
	var specimens := _player.inventory.get_specimens(definition_id)
	var best_quality := specimens[0].quality if not specimens.is_empty() else 0.0
	var freshness_total := 0.0
	for specimen: ItemInstance in specimens:
		freshness_total += specimen.freshness
	var average_freshness := freshness_total / maxf(1.0, float(specimens.size()))
	var metabolism := _consumable_profile_text(definition as ConsumableDefinition) if definition is ConsumableDefinition else ""
	inventory_detail_body.text = "%s%s\n\nВ СУМКЕ ×%.0f   ·   %.2f КГ   ·   %.2f Л" % [
		definition.description, metabolism, _player.inventory.count(definition_id), unit_mass, unit_volume,
	]
	inventory_quality_bar.value = best_quality
	inventory_freshness_bar.value = average_freshness
	inventory_specimen_list.clear()
	(inventory_specimen_list as InventorySpecimenList).configure_drag_preview(_inventory_icon(definition), definition.display_name)
	for index in specimens.size():
		var specimen := specimens[index]
		var part := String(specimen.processing_state.get(&"part", "целый образец"))
		inventory_specimen_list.add_item("#%02d  %s  ·  качество %d%%  ·  свежесть %d%%" % [
			index + 1, part, roundi(specimen.quality * 100.0), roundi(specimen.freshness * 100.0),
		])
		inventory_specimen_list.set_item_metadata(index, {
			"kind": &"inventory_item",
			"definition_id": definition_id,
			"instance_id": specimen.instance_id,
			"consumable": definition is ConsumableDefinition,
		})
	if not specimens.is_empty():
		inventory_specimen_list.select(0)
		_selected_inventory_instance_id = specimens[0].instance_id
	inventory_use_button.disabled = not definition is ConsumableDefinition
	inventory_use_button.text = "Принять" if definition is ConsumableDefinition else "Не употребляется"
	if definition is IngredientDefinition and _cooking != null:
		inventory_use_button.disabled = specimens.is_empty()
		inventory_use_button.text = "Для лаборатории"
	if definition is ToolDefinition:
		inventory_use_button.disabled = specimens.is_empty()
		inventory_use_button.text = "Убрать из рук" if _player.toolbelt.is_equipped and _player.toolbelt.active_tool_id == definition_id else "Взять в руки"
	inventory_drop_button.disabled = specimens.is_empty()
	inventory_drop_button.text = "Выложить в мир"


func _consumable_profile_text(definition: ConsumableDefinition) -> String:
	if definition == null:
		return ""
	var minutes := ceili(definition.nutrition_duration_seconds / 60.0)
	var lines: Array[String] = []
	if definition.maximum_health_bonus != 0.0:
		lines.append("ЗДОРОВЬЕ  %+d" % roundi(definition.maximum_health_bonus))
	if definition.maximum_stamina_bonus != 0.0:
		lines.append("ВЫНОСЛИВОСТЬ  %+d" % roundi(definition.maximum_stamina_bonus))
	if definition.health_regeneration > 0.0:
		lines.append("ВОССТАНОВЛЕНИЕ  +%.1f/с" % definition.health_regeneration)
	if definition.warmth_bonus > 0.0 or definition.cold_resistance_bonus > 0.0:
		lines.append("ТЕПЛОЗАЩИТА  %d%%" % roundi(maxf(definition.warmth_bonus, definition.cold_resistance_bonus) * 100.0))
	if definition.spore_resistance_bonus != 0.0:
		lines.append("ЗАЩИТА ОТ СПОР  %+d%%" % roundi(definition.spore_resistance_bonus * 100.0))
	if definition.toxicity > 0.0:
		lines.append("ТОКСИЧЕСКАЯ НАГРУЗКА  +%d%%" % roundi(definition.toxicity * 100.0))
	if lines.is_empty():
		return ""
	return "\n\nЭФФЕКТ · %d МИН · %s\n%s" % [minutes, String(definition.nutrition_group).to_upper(), "   ·   ".join(lines)]


func _use_selected_inventory_item() -> void:
	if _player == null or _selected_inventory_instance_id == &"":
		return
	if ContentDB.get_definition(_selected_inventory_id) is IngredientDefinition and _cooking != null:
		if _cooking.select_inventory_specimen(_player.inventory, _selected_inventory_instance_id):
			show_notice("Образец выбран. Подойди к рабочему инструменту лаборатории.")
		return
	if ContentDB.get_definition(_selected_inventory_id) is ToolDefinition:
		if _player.toolbelt.is_equipped and _player.toolbelt.active_tool_id == _selected_inventory_id:
			_player.toolbelt.unequip()
		else:
			_player.toolbelt.equip(_selected_inventory_id)
		_update_inventory_panel()
		return
	if _player.inventory.use_consumable_instance(_selected_inventory_instance_id):
		audio_cue_requested.emit(&"confirm")
		_update_inventory_panel()


func _drop_selected_inventory_item() -> void:
	if _player == null or _selected_inventory_instance_id == &"":
		return
	var definition := ContentDB.get_definition(_selected_inventory_id)
	var display_name := definition.display_name if definition != null else String(_selected_inventory_id)
	if _player.drop_inventory_item(_selected_inventory_instance_id):
		audio_cue_requested.emit(&"confirm")
		show_notice("ВЫЛОЖЕНО В МИР · %s · можно поднять обратно" % display_name)
		_update_inventory_panel()


func _on_inventory_payload_dropped(action: StringName, payload: Dictionary) -> void:
	var instance_id := StringName(payload.get("instance_id", &""))
	if instance_id == &"":
		return
	_selected_inventory_id = StringName(payload.get("definition_id", &""))
	_selected_inventory_instance_id = instance_id
	match action:
		&"consume":
			_use_selected_inventory_item()
		&"drop":
			_drop_selected_inventory_item()


func _set_inventory_filter(filter_id: StringName) -> void:
	_inventory_filter = filter_id
	_selected_inventory_id = &""
	_selected_inventory_instance_id = &""
	audio_cue_requested.emit(&"select")
	_refresh_inventory_filter_buttons()
	_update_inventory_panel()


func _set_inventory_sort(index: int) -> void:
	var modes: Array[StringName] = [&"name", &"quality", &"quantity", &"freshness"]
	_inventory_sort_mode = modes[clampi(index, 0, modes.size() - 1)]
	audio_cue_requested.emit(&"select")
	_update_inventory_panel()


func _on_inventory_specimen_selected(index: int) -> void:
	if index < 0 or index >= inventory_specimen_list.item_count:
		return
	var selected_text := inventory_specimen_list.get_item_text(index)
	var payload: Variant = inventory_specimen_list.get_item_metadata(index)
	if payload is Dictionary:
		_selected_inventory_instance_id = StringName(payload.get("instance_id", &""))
	inventory_detail_title.text = "%s · %s" % [
		ContentDB.get_definition(_selected_inventory_id).display_name,
		selected_text.get_slice("  ·  ", 0),
	]


func _inventory_icon(definition: ContentDefinition) -> Texture2D:
	if definition is IngredientDefinition:
		return (definition as IngredientDefinition).inventory_icon
	if definition is ItemDefinition:
		return (definition as ItemDefinition).inventory_icon
	return null


func _inventory_fallback_glyph(definition: ContentDefinition) -> String:
	if definition is ConsumableDefinition:
		return "◇"
	if definition is IngredientDefinition:
		return "✦"
	return "◈"


func _first_inventory_button() -> Button:
	for card: Node in inventory_list.get_children():
		if card.get_child_count() > 0 and card.get_child(0) is Button:
			return card.get_child(0) as Button
	return null


func _refresh_inventory_filter_buttons() -> void:
	var mapping: Dictionary[StringName, Button] = {
		&"all": $"InventoryPanel/Margin/Layout/FilterBar/InventoryFilterAll",
		&"ingredients": $"InventoryPanel/Margin/Layout/FilterBar/InventoryFilterIngredients",
		&"consumables": $"InventoryPanel/Margin/Layout/FilterBar/InventoryFilterConsumables",
		&"tools": $"InventoryPanel/Margin/Layout/FilterBar/InventoryFilterTools",
	}
	for filter_id: StringName in mapping:
		mapping[filter_id].button_pressed = filter_id == _inventory_filter


func _animate_inventory_open() -> void:
	inventory_panel.pivot_offset = inventory_panel.size * 0.5
	inventory_panel.modulate.a = 0.0
	inventory_panel.scale = Vector2(0.985, 0.985)
	inventory_scrim.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(inventory_panel, "modulate:a", 1.0, 0.22)
	tween.tween_property(inventory_panel, "scale", Vector2.ONE, 0.26)
	tween.tween_property(inventory_scrim, "modulate:a", 1.0, 0.18)


func _inventory_parts_summary(parts: Array) -> String:
	if parts.is_empty():
		return "ЦЕЛЫЙ ОБРАЗЕЦ"
	var labels := PackedStringArray()
	for part: Variant in parts:
		labels.append(String(part).to_upper())
	return " / ".join(labels)


func _inventory_definition_matches_filter(definition: ContentDefinition) -> bool:
	match _inventory_filter:
		&"ingredients": return definition is IngredientDefinition
		&"consumables": return definition is ConsumableDefinition
		&"tools": return definition is ItemDefinition and not definition is ConsumableDefinition
		_: return true


func _inventory_category_title(definition: ContentDefinition) -> String:
	if definition is ConsumableDefinition:
		return "СОСТАВ"
	if definition is IngredientDefinition:
		return "СЫРЬЁ"
	return "СНАРЯЖЕНИЕ"


func _inventory_category_color(definition: ContentDefinition) -> Color:
	if definition is ConsumableDefinition:
		return Color("e89555")
	if definition is IngredientDefinition:
		return Color("b7d36f")
	return Color("82b9c7")


func _update_journal() -> void:
	journal_entry_list.clear()
	_journal_entries.clear()
	match _journal_mode:
		&"hypotheses":
			if _hypotheses != null:
				_journal_entries = _hypotheses.get_entries()
			for entry: Dictionary in _journal_entries:
				var state := "ПОДТВЕРЖДЕНО" if bool(entry["verified"]) else "%d/%d ПРИЗНАКОВ" % [(entry["found_ids"] as Array).size(), (entry["required_ids"] as Array).size()]
				journal_entry_list.add_item("%s  ·  %s" % [String(entry["question"]), state])
		&"recipes":
			if _recipe_knowledge != null:
				_journal_entries = _recipe_knowledge.get_entries()
			for entry: Dictionary in _journal_entries:
				var state := "ОСВОЕНО" if bool(entry["learned"]) else "ГИПОТЕЗА · %d ПРОБ" % int(entry.get("attempt_count", 0))
				journal_entry_list.add_item("%s  ·  %s" % [String(entry["title"]), state])
		_:
			if _knowledge != null:
				for definition_id: StringName in _knowledge.get_known_definition_ids():
					var definition := ContentDB.get_definition(definition_id)
					_journal_entries.append({"id": definition_id, "definition": definition})
					var level_names := ["НЕИЗВЕСТНО", "НАБЛЮДЕНИЕ", "ОБРАЗЕЦ", "ИЗУЧЕНО"]
					var icon := (definition as IngredientDefinition).inventory_icon if definition is IngredientDefinition else null
					journal_entry_list.add_item("%s  ·  %s" % [definition.display_name if definition != null else String(definition_id), level_names[_knowledge.get_level(definition_id)]], icon)
	journal_counter.text = "%d ЗАПИСЕЙ" % _journal_entries.size()
	if _journal_entries.is_empty():
		_show_empty_journal()
		return
	var selected_index := 0
	for index in _journal_entries.size():
		if StringName(_journal_entries[index].get("id", &"")) == _selected_journal_id:
			selected_index = index
			break
	journal_entry_list.select(selected_index)
	_select_journal_entry(selected_index)


func _set_journal_mode(mode: StringName) -> void:
	_journal_mode = mode
	_selected_journal_id = &""
	$"JournalPanel/Margin/Layout/JournalTabs/JournalTabSpecies".button_pressed = mode == &"species"
	$"JournalPanel/Margin/Layout/JournalTabs/JournalTabHypotheses".button_pressed = mode == &"hypotheses"
	$"JournalPanel/Margin/Layout/JournalTabs/JournalTabRecipes".button_pressed = mode == &"recipes"
	audio_cue_requested.emit(&"select")
	_update_journal()


func _select_journal_entry(index: int) -> void:
	if index < 0 or index >= _journal_entries.size():
		_show_empty_journal()
		return
	var entry := _journal_entries[index]
	_selected_journal_id = StringName(entry.get("id", &""))
	match _journal_mode:
		&"hypotheses": _show_hypothesis_entry(entry)
		&"recipes": _show_recipe_entry(entry)
		_: _show_species_entry(entry)


func _show_species_entry(entry: Dictionary) -> void:
	var definition_id := StringName(entry["id"])
	var definition := entry.get("definition") as ContentDefinition
	var level := _knowledge.get_level(definition_id)
	var level_names := ["НЕИЗВЕСТНО", "НАБЛЮДЕНИЕ", "ОБРАЗЕЦ ПОЛУЧЕН", "ИЗУЧЕНО"]
	journal_detail_kicker.text = "КАРТОЧКА ВИДА · %s" % level_names[level]
	journal_detail_title.text = definition.display_name if definition != null else String(definition_id)
	var clue_ids := _knowledge.get_discovered_clue_ids(definition_id)
	var clue_total := _knowledge.get_clue_total(definition_id)
	journal_detail_meta.text = "ПРИЗНАКИ  %d/%d   ·   ОБРАЗЦЫ В СУМКЕ  × %.0f" % [clue_ids.size(), clue_total, _player.inventory.count(definition_id) if _player != null else 0.0]
	journal_progress.value = float(clue_ids.size()) / float(clue_total) if clue_total > 0 else float(level) / float(KnowledgeOrchestrator.Level.UNDERSTOOD)
	var body := "[color=#99a395]ПОЛЕВОЕ ОПИСАНИЕ[/color]\n%s\n\n" % (definition.description if definition != null else "Описание отсутствует.")
	if definition is IngredientDefinition:
		var ingredient := definition as IngredientDefinition
		if not ingredient.biome_tags.is_empty():
			body += "[color=#99a395]СРЕДА[/color]\n%s\n\n" % ", ".join(PackedStringArray(ingredient.biome_tags))
		body += "[color=#99a395]МОРФОЛОГИЧЕСКИЕ ПРИЗНАКИ[/color]\n"
		if ingredient.inspection_clues.is_empty():
			body += "Наблюдения ещё не систематизированы."
		for clue: InspectionClueDefinition in ingredient.inspection_clues:
			var found := clue.id in clue_ids
			body += "%s  [b]%s[/b]\n%s\n\n" % ["✓" if found else "○", clue.label if found else "Неразобранный признак", clue.description if found else "Осмотрите образец под другим углом."]
	journal_detail_body.text = body


func _show_hypothesis_entry(entry: Dictionary) -> void:
	var found_ids := entry["found_ids"] as Array
	var required_ids := entry["required_ids"] as Array
	journal_detail_kicker.text = "ГИПОТЕЗА · %s" % ("ПОДТВЕРЖДЕНА" if bool(entry["verified"]) else "В РАБОТЕ")
	journal_detail_title.text = String(entry["question"])
	journal_detail_meta.text = "%d ИЗ %d НАБЛЮДЕНИЙ СОШЛИСЬ" % [found_ids.size(), required_ids.size()]
	journal_progress.value = float(found_ids.size()) / maxf(1.0, float(required_ids.size()))
	var body := "%s\n\n[color=#99a395]ЦЕПОЧКА ДОКАЗАТЕЛЬСТВ[/color]\n" % String(entry.get("description", ""))
	for clue_id: StringName in required_ids:
		body += "%s  %s\n" % ["✓" if clue_id in found_ids else "○", String(clue_id).get_slice(".", String(clue_id).count("."))]
	var suggested := entry.get("suggested_item_ids", []) as Array
	if not suggested.is_empty():
		body += "\n[color=#99a395]СВЯЗАННЫЕ ОБРАЗЦЫ[/color]\n"
		for item_id: StringName in suggested:
			var definition := ContentDB.get_definition(item_id)
			body += "• %s\n" % (definition.display_name if definition != null else String(item_id))
	journal_detail_body.text = body


func _show_recipe_entry(entry: Dictionary) -> void:
	journal_detail_kicker.text = "ФОРМУЛА · %s" % ("ОСВОЕНА" if bool(entry["learned"]) else "НЕПРОВЕРЕННАЯ ЗАПИСЬ")
	journal_detail_title.text = String(entry["title"])
	var primary := ContentDB.get_definition(entry["primary_ingredient_id"])
	var result := ContentDB.get_definition(entry["result_item_id"])
	var base_names: Dictionary = {&"base.water": "РОДНИКОВАЯ ВОДА", &"base.kvass": "КИСЛЫЙ КВАС", &"base.spirit": "ХЛЕБНЫЙ СПИРТ"}
	var finish_names := ["РАЗЛИВ", "ПЕРЕГОНКА", "ПОРЦИЯ"]
	journal_detail_meta.text = "%s   ·   %s   ·   ЛАБОРАТОРИЯ %d" % [base_names.get(StringName(entry["base_id"]), String(entry["base_id"])), finish_names[int(entry["finish_method"])], int(entry["station_tier"])]
	journal_progress.value = 1.0 if bool(entry["learned"]) else minf(0.8, 0.25 + float(entry.get("attempt_count", 0)) * 0.1)
	var operation_names: Dictionary = {&"wash": "ПРОМЫТЬ", &"slice": "РАЗДЕЛИТЬ", &"grind": "РАСТОЛОЧЬ", &"heat": "ВЫДЕРЖАТЬ"}
	var body := "[color=#99a395]ПОЛЕВАЯ ЗАПИСЬ[/color]\n%s\n\n%s\n\n[color=#99a395]ПОРЯДОК РАБОТЫ[/color]\n" % [String(entry.get("description", "")), String(entry["field_notes"])]
	var index := 1
	for step: Dictionary in entry.get("steps", []):
		body += "%d. [color=#c6d98a]%s[/color]  %s\n" % [index, operation_names.get(StringName(step["operation"]), String(step["operation"]).to_upper()), String(step["hint"])]
		if StringName(step["operation"]) == &"heat":
			body += "   %d–%d°C · %d–%d c · часы %d–%d\n" % [roundi(step["temperature_min"]), roundi(step["temperature_max"]), roundi(step["duration_min"]), roundi(step["duration_max"]), int(step["turns_min"]), int(step["turns_max"])]
			var cue := StringName(step.get("sensory_cue", &""))
			if cue != &"":
				body += "   Признак готовности: [color=#c6d98a]%s[/color]\n" % ThermalVesselState.cue_title(cue).capitalize()
		index += 1
	var observations := entry.get("observations", []) as Array
	if not observations.is_empty():
		body += "\n[color=#99a395]НАБЛЮДЕНИЯ ПОСЛЕ ПРОБ[/color]\n"
		for observation: Variant in observations:
			body += "• %s\n" % String(observation)
	body += "\n[color=#99a395]ОЖИДАЕМЫЙ РЕЗУЛЬТАТ[/color]\n%s · базовый выход ×%d" % [result.display_name if result != null else String(entry["result_item_id"]), int(entry["base_yield"])]
	journal_detail_body.text = body


func _on_recipe_observation_added(_recipe_id: StringName, message: String) -> void:
	show_notice("ЛАБОРАТОРНАЯ ЗАПИСЬ · %s" % message)
	_update_journal()


func _show_empty_journal() -> void:
	journal_detail_kicker.text = "АРХИВ ПУСТ"
	journal_detail_title.text = "Нет записей в этом разделе"
	journal_detail_meta.text = "Осматривайте растения, проверяйте гипотезы и готовьте составы."
	journal_progress.value = 0.0
	journal_detail_body.text = "[color=#99a395]ПОДСКАЗКА[/color]\n[F] открывает осмотр объекта. Найденные признаки автоматически связываются с карточкой вида."
