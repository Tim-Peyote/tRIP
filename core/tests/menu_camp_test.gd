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
	var backdrop := (load("res://features/frontend/menu_camp_backdrop.tscn") as PackedScene).instantiate() as MenuCampBackdrop
	add_child(backdrop)
	var actor := backdrop.get_node("SeatedResearcher/GEOBody")
	_expect(actor.scene_file_path == "res://assets/models/actors/geo_researcher.glb", "Menu must use the same GEO body as the player.")
	var actor_animation := actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_expect(actor_animation != null and actor_animation.current_animation == "Human Armature|Seated", "Menu actor is not playing the seated animation.")
	_expect(backdrop.has_node("CedarClearing"), "Menu must instance the Blender clearing.")
	var clearing := backdrop.get_node_or_null("CedarClearing")
	if clearing != null:
		_expect(clearing.get_child_count() >= 20, "Imported grove or camp equipment is missing.")
		_expect(clearing.find_child("Cube", true, false) == null, "Blender default cube leaked into export.")
		var textured_surfaces := 0
		for node in clearing.find_children("*", "MeshInstance3D", true, false):
			var part := node as MeshInstance3D
			for surface in part.mesh.get_surface_count():
				var material := part.get_surface_override_material(surface)
				if material is StandardMaterial3D and material.albedo_texture != null:
					textured_surfaces += 1
				elif material is ShaderMaterial and material.get_shader_parameter("rock_texture") != null:
					textured_surfaces += 1
		_expect(textured_surfaces >= 23, "Menu lost shared bark, ground or granite texture materials.")
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
