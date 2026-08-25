extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	InputBootstrap.ensure_defaults()
	ContentDB.rebuild()
	var level := (load("res://world/levels/shelter/shelter_level.tscn") as PackedScene).instantiate() as ShelterLevel
	add_child(level)
	level.expedition_clock.running = false
	level.initialize_new_session()
	var laboratory := level.get_road_laboratory()
	var architecture := level.get_node("Architecture") as Node3D
	var old_door := level.get_node("ForestDoor") as Node3D
	var portable_root := laboratory.get_node("PortableLaboratory") as Node3D
	var cairn := laboratory.get_node("FirstRitualCairn") as RitualCairn
	_expect(not architecture.visible, "A new run still exposes the legacy indoor laboratory.")
	_expect(not old_door.visible, "A new run still exposes the old biome door.")
	_expect(level.player.global_position.z > 8.0, "A new run did not place the player in the expedition world.")
	_expect(not laboratory.unlocked and not portable_root.visible, "The road laboratory was available before the ritual.")
	_expect(cairn.visible, "The first ritual cairn was not placed in the ordinary world.")
	var interactable := cairn.find_children("*", "InteractableComponent", true, false)[0] as InteractableComponent
	interactable.complete_interaction(level.player)
	await get_tree().process_frame
	_expect(laboratory.is_metamorphosing(), "The ritual skipped the laboratory metamorphosis stage.")
	_expect(portable_root.visible, "The laboratory silhouette was not visible during metamorphosis.")
	for node: Node in portable_root.find_children("*", "InteractableComponent", true, false):
		_expect(not (node as InteractableComponent).enabled, "A laboratory interaction was enabled before metamorphosis finished.")
	for node: Node in portable_root.find_children("*", "CollisionShape3D", true, false):
		_expect((node as CollisionShape3D).disabled, "Laboratory collision could trap the player while space was still folding.")
	await get_tree().create_timer(1.5).timeout
	_expect(laboratory.unlocked and laboratory.manifested, "The ritual did not manifest the road laboratory.")
	_expect(portable_root.visible, "The manifested laboratory remained invisible.")
	_expect(portable_root.get_node_or_null("Table") != null, "Cooking equipment was not moved into the portable laboratory.")
	var dressing := portable_root.get_node_or_null("AuthoredLaboratoryDressing") as PortableLaboratoryDressing
	_expect(dressing != null, "The portable laboratory has no authored camp dressing.")
	if dressing != null:
		_expect(dressing.authored_model_count >= 24, "The portable laboratory is still built from a sparse placeholder set.")
		for model_name: String in ["FieldTent", "WeatherCanvas", "CampfirePit", "CookingTripod"]:
			_expect(dressing.get_node_or_null(model_name) != null, "Missing authored laboratory model: %s." % model_name)
	var cauldron := portable_root.get_node_or_null("Cauldron") as Node3D
	var table := portable_root.get_node_or_null("Table") as Node3D
	_expect(cauldron != null and cauldron.get_node_or_null("CastIronPot") != null, "The cooking vessel is still a placeholder primitive.")
	_expect(table != null and table.get_node_or_null("AuthoredWorkbench") != null, "The preparation table is still a placeholder primitive.")
	if cauldron != null and table != null:
		_expect(cauldron.position.distance_to(table.position) > 1.5, "Heat and preparation stations still overlap and compete for interaction focus.")
	_expect(not laboratory.is_metamorphosing(), "Laboratory remained busy after manifestation.")
	var enabled_interactions := 0
	for node: Node in portable_root.find_children("*", "InteractableComponent", true, false):
		if (node as InteractableComponent).enabled:
			enabled_interactions += 1
	_expect(enabled_interactions > 0, "Laboratory interactions did not activate after metamorphosis.")
	var physical_roles: Dictionary[String, bool] = {}
	for node: Node in portable_root.find_children("*", "PhysicalCookingStationComponent", true, false):
		var station := node as PhysicalCookingStationComponent
		physical_roles[station.role] = station.orchestrator != null
	for expected_role: String in ["add_water", "add_kvass", "add_spirit", "transfer", "cycle_heat", "stir", "bottle", "distill", "serve", "vessel_position", "bellows", "hourglass"]:
		_expect(physical_roles.get(expected_role, false), "Portable workflow role is missing or unbound: %s." % expected_role)
	for node: Node in portable_root.find_children("*", "CookingToolComponent", true, false):
		_expect((node as CookingToolComponent).orchestrator != null, "Preparation tool was not bound to the cooking orchestrator: %s." % node.get_path())
	laboratory.dismiss(true)
	await get_tree().process_frame
	_expect(laboratory.is_metamorphosing(), "Animated laboratory dismissal skipped metamorphosis.")
	for node: Node in portable_root.find_children("*", "InteractableComponent", true, false):
		_expect(not (node as InteractableComponent).enabled, "Interaction remained active while the laboratory was disappearing.")
	await get_tree().create_timer(1.5).timeout
	_expect(not laboratory.manifested and not portable_root.visible, "Laboratory remained in the world after dismissal.")
	_expect(laboratory.developer_toggle(false), "Developer instant laboratory toggle was rejected while idle.")
	_expect(laboratory.manifested and portable_root.visible, "Developer instant toggle did not restore the laboratory.")
	var save_data := laboratory.to_save_data()
	_expect(bool(save_data.get("unlocked", false)), "Ritual unlock state was not serializable.")
	_expect((save_data.get("laboratory_position", []) as Array).size() == 3, "Laboratory position was not serializable.")
	_expect(save_data.has("laboratory_yaw"), "Laboratory orientation was not serialized and would rotate after loading.")
	level.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip road laboratory test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip road laboratory test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
