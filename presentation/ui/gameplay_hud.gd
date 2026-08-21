class_name GameplayHUD
extends Control

signal resume_requested
signal main_menu_requested

@onready var prompt_label: Label = %PromptLabel
@onready var hold_progress: ProgressBar = %HoldProgress
@onready var notice_label: Label = %NoticeLabel
@onready var inventory_label: Label = %InventoryLabel
@onready var pause_panel: PanelContainer = %PausePanel
@onready var notice_timer: Timer = %NoticeTimer
@onready var inspection_panel: PanelContainer = %InspectionPanel
@onready var inventory_panel: PanelContainer = %InventoryPanel
@onready var inspection_view: SampleInspectionView = %SampleInspectionView

var _player: FirstPersonController
var _cooking: CookingOrchestrator
var _knowledge: KnowledgeOrchestrator
var _objective: ExpeditionObjectiveOrchestrator
var _clock: ExpeditionClock
var _stealth: StealthOrchestrator
var _hypotheses: HypothesisOrchestrator
var _game_loop: GameLoopOrchestrator
var _persistence: SessionPersistenceOrchestrator
var _spore_tide: SporeTideOrchestrator


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%ResumeButton.pressed.connect(func() -> void: resume_requested.emit())
	%MainMenuButton.pressed.connect(func() -> void: main_menu_requested.emit())
	%ContinueCycleButton.pressed.connect(_acknowledge_cycle_result)
	notice_timer.timeout.connect(func() -> void: notice_label.visible = false)


func setup(player: FirstPersonController) -> void:
	_player = player
	player.interactor.prompt_changed.connect(_on_prompt_changed)
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
	inspection_view.closed.connect(_on_inspection_closed)
	visible = true
	set_paused(false)
	_update_inventory_label()
	%ToolLabel.text = player.toolbelt.get_display_name() + "  [Q]"
	_on_distraction_count_changed(player.distraction_thrower.remaining)


func setup_cooking(cooking: CookingOrchestrator) -> void:
	_cooking = cooking
	cooking.action_recorded.connect(_on_cooking_action_recorded)
	cooking.action_rejected.connect(show_notice)
	cooking.result_created.connect(_on_cooking_result_created)
	cooking.vessel_state_changed.connect(_on_vessel_state_changed)
	cooking.physical_action_recorded.connect(_on_physical_cooking_action)
	_on_vessel_state_changed(cooking.vessel)


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


func clear() -> void:
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
	prompt_label.text = ""
	hold_progress.visible = false
	notice_label.visible = false
	inspection_panel.visible = false
	inspection_view.visible = false
	inventory_panel.visible = false
	%JournalPanel.visible = false
	%CycleResultPanel.visible = false
	visible = false


func set_paused(is_paused: bool) -> void:
	pause_panel.visible = is_paused
	if is_paused:
		%ResumeButton.grab_focus()


func _on_prompt_changed(text: String) -> void:
	prompt_label.text = text


func _on_hold_progress_changed(progress: float) -> void:
	hold_progress.value = progress * 100.0
	hold_progress.visible = progress > 0.0


func _on_item_added(item: ItemInstance, display_name: String) -> void:
	var part := String(item.processing_state.get(&"part", ""))
	var quality := ""
	if not part.is_empty():
		quality = " · %s · качество %d%%" % [part, roundi(item.quality * 100.0)]
	show_notice("В сумке: %s%s" % [display_name, quality])
	_update_inventory_label()


func _on_item_rejected(_definition_id: StringName, reason: String) -> void:
	show_notice("Не помещается: %s" % reason)


func _on_inventory_changed() -> void:
	_update_inventory_label()
	_update_inventory_panel()


func _on_consumable_used(_effect_ids: Array[StringName], display_name: String) -> void:
	show_notice("Принято: %s" % display_name)


func _on_cooking_action_recorded(operation: StringName, step_count: int) -> void:
	var verbs: Dictionary = {
		&"grind": "Образец измельчён и готов к переносу",
		&"heat": "Смесь выдержана на слабом огне",
	}
	show_notice("%s  ·  этап %d" % [verbs.get(operation, String(operation)), step_count])


func _on_cooking_result_created(result: RecipeResolution, display_name: String) -> void:
	var quality_names := ["испорчено", "нестабильно", "рабочее", "чистое", "открытие"]
	show_notice("Готово: %s · %s · [1] применить" % [display_name, quality_names[result.quality]])


func _on_vessel_state_changed(state: ThermalVesselState) -> void:
	%CookingStatusLabel.text = state.get_stage_text()
	%CookingStatusLabel.visible = state.water_amount > 0.0 or state.heat_level != ThermalVesselState.HeatLevel.OFF


func _on_physical_cooking_action(action: StringName) -> void:
	var messages: Dictionary = {
		&"add_water": "В котёл налита холодная вода",
		&"transfer": "Измельчённая шляпка добавлена в воду",
		&"heat_0": "Очаг погашен",
		&"heat_1": "Слабый огонь",
		&"heat_2": "Сильный огонь — следи за температурой",
		&"stir": "Состав перемешан",
	}
	if messages.has(action):
		show_notice(messages[action])


func _on_tool_state_changed(display_name: String, _is_equipped: bool) -> void:
	%ToolLabel.text = display_name + "  [Q]"
	show_notice(display_name)


func _toggle_inventory() -> void:
	inventory_panel.visible = not inventory_panel.visible
	_update_inventory_panel()


func _toggle_journal() -> void:
	%JournalPanel.visible = not %JournalPanel.visible
	_update_journal()


func _on_knowledge_changed(_definition_id: StringName, _level: int) -> void:
	_update_journal()
	show_notice("Гербарий обновлён · [J]")


func _on_hypothesis_updated(_hypothesis_id: StringName, is_verified: bool) -> void:
	_update_journal()
	if is_verified:
		show_notice("Гипотеза подтверждена · новый рецепт обоснован")


func _on_objective_updated(text: String) -> void:
	%ObjectiveLabel.text = text


func _on_loop_stage_changed(_stage: int, objective_text: String) -> void:
	%ObjectiveLabel.text = objective_text


func _on_narrative_notice_requested(title: String, text: String) -> void:
	show_notice("%s · %s" % [title, text])


func _on_cycle_result_ready(summary: Dictionary) -> void:
	%CycleResultTitle.text = String(summary.get("title", "ЦИКЛ ЗАВЕРШЁН"))
	%CycleResultBody.text = "Качество состава: %s\nТочность процесса: %d%%\nВремя вылазки: %02d:%02d\nИзучено признаков: %d\n\nНАГРАДА\n%s" % [
		String(summary.get("quality", "—")),
		int(summary.get("score", 0)),
		int(summary.get("expedition_seconds", 0)) / 60,
		int(summary.get("expedition_seconds", 0)) % 60,
		int(summary.get("knowledge", 0)),
		String(summary.get("reward", "—")),
	]
	%CycleResultPanel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	%ContinueCycleButton.grab_focus()


func _acknowledge_cycle_result() -> void:
	%CycleResultPanel.visible = false
	if _game_loop != null:
		_game_loop.acknowledge_reward()
	if _player != null:
		_player.capture_mouse()


func _on_session_saved(_slot_id: int, _reason: StringName) -> void:
	%SaveIndicator.visible = true
	%SaveIndicatorTimer.start()


func _on_clock_changed(_progress: float) -> void:
	if _clock != null:
		%ClockLabel.text = _clock.get_display_text()


func _on_threat_changed(value: float, state_text: String) -> void:
	%ThreatBar.value = value * 100.0
	%ThreatBar.visible = value > 0.01
	%ThreatLabel.text = state_text
	%ThreatLabel.modulate = Color(0.9, 0.32, 0.2) if value >= 0.55 else Color(0.68, 0.76, 0.54)


func _on_distraction_count_changed(remaining: int) -> void:
	%DistractionLabel.text = "КАМНИ  %d  [G]" % remaining


func _on_spore_tide_state_changed(state: int, label: String) -> void:
	%SporeTideLabel.text = label
	%SporeTideLabel.visible = state != SporeTideOrchestrator.State.CALM


func _on_spore_exposure_changed(value: float) -> void:
	%SporeTideBar.value = value * 100.0
	%SporeTideBar.visible = value > 0.01


func _on_spore_shelter_changed(is_sheltered: bool, shelter_name: String) -> void:
	%SporeShelterLabel.visible = is_sheltered
	%SporeShelterLabel.text = "УКРЫТИЕ · %s" % shelter_name.to_upper()


func _on_inspection_requested(title: String, description: String) -> void:
	%InspectionTitle.text = title
	%InspectionDescription.text = description
	inspection_panel.visible = not inspection_panel.visible


func _on_inspection_definition_requested(definition_id: StringName, title: String, description: String) -> void:
	if not inspection_view.open_definition(definition_id):
		_on_inspection_requested(title, description)
		return
	inspection_panel.visible = false
	_player.interactor.set_process(false)
	prompt_label.visible = false


func _on_inspection_closed() -> void:
	if _player == null:
		return
	_player.interactor.set_process(true)
	_player.capture_mouse()
	prompt_label.visible = true


func show_notice(text: String) -> void:
	notice_label.text = text
	notice_label.visible = true
	notice_timer.start()


func _update_inventory_label() -> void:
	if _player == null:
		inventory_label.text = ""
		return
	inventory_label.text = "СУМКА  %d / %.1f" % [_player.inventory.items.size(), _player.inventory.maximum_volume]


func _update_inventory_panel() -> void:
	if _player == null:
		%InventoryContents.text = ""
		return
	var lines := _player.inventory.get_display_lines()
	%InventoryContents.text = "Сумка пуста" if lines.is_empty() else "\n".join(lines)


func _update_journal() -> void:
	if _knowledge == null:
		%JournalContents.text = "Пока нет наблюдений."
		return
	var lines := _knowledge.get_display_lines()
	var sections := PackedStringArray()
	sections.append("Осматривайте растения [F], чтобы делать записи." if lines.is_empty() else "\n".join(lines))
	if _hypotheses != null:
		var hypothesis_lines := _hypotheses.get_display_lines()
		if not hypothesis_lines.is_empty():
			sections.append("ГИПОТЕЗЫ\n" + "\n".join(hypothesis_lines))
	%JournalContents.text = "\n\n".join(sections)
