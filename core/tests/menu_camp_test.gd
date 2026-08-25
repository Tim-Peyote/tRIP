extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var old_mode := SettingsService.get_window_mode()
	var old_resolution := SettingsService.get_resolution()
	SettingsService.set_window_mode(&"borderless")
	SettingsService.set_resolution(Vector2i(1600, 900))
	_expect(SettingsService.get_window_mode() == &"borderless", "Display mode was not persisted.")
	_expect(SettingsService.get_resolution() == Vector2i(1600, 900), "Window resolution was not persisted.")
	SettingsService.set_resolution(old_resolution)
	SettingsService.set_window_mode(old_mode)
	var backdrop := MenuCampBackdrop.new()
	add_child(backdrop)
	backdrop.apply_progress_data({})
	_expect(backdrop.get_laboratory_level() == 0, "A fresh save must show the field laboratory at level zero.")
	_expect(backdrop.get_visible_upgrade_names().is_empty(), "A fresh save must not show persistent upgrades.")
	backdrop.apply_progress_data({"completed_cycles": 1})
	_expect(backdrop.get_laboratory_level() == 1, "One completed cycle must unlock laboratory level one.")
	_expect(backdrop.get_visible_upgrade_names().has("DryingRack"), "Laboratory level one must show the drying rack.")
	backdrop.apply_progress_data({
		"completed_cycles": 1,
		"second_expedition_complete": true,
		"counteragent_brewed": true,
		"root_well_plan": "warded_descent",
	})
	_expect(backdrop.get_laboratory_level() == 4, "Story discoveries must raise the laboratory to level four.")
	var upgrades := backdrop.get_visible_upgrade_names()
	_expect(upgrades.has("DryingRack"), "Advanced camp lost its drying rack.")
	_expect(upgrades.has("SporeFilter"), "Second expedition must unlock the spore filter.")
	_expect(upgrades.has("DistillerCoil"), "Counteragent knowledge must unlock the distiller.")
	_expect(upgrades.has("RootResonator"), "Root-well decision must unlock the resonator.")
	backdrop.apply_progress_data({"story_phase_id": "phase.distant_heart"})
	_expect(backdrop.get_laboratory_level() == 6, "Final story world must raise the persistent laboratory to level six.")
	var final_upgrades := backdrop.get_visible_upgrade_names()
	_expect(final_upgrades.has("MirrorSeparator"), "Mirror world did not persist its separator module.")
	_expect(final_upgrades.has("ConcordanceCoil"), "Final world did not persist its concordance coil.")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip menu camp test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip menu camp test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
