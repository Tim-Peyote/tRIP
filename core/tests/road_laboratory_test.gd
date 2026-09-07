extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	InputBootstrap.ensure_defaults()
	ContentDB.rebuild()
	var level := (load("res://world/levels/expedition_session.tscn") as PackedScene).instantiate() as SessionController
	add_child(level)
	level.expedition_clock.running = false
	level.initialize_new_session()
	var laboratory := level.get_road_laboratory()
	var portable_root := laboratory.get_laboratory_root() as Node3D
	var cairn := laboratory.get_node("FirstRitualCairn") as RitualCairn
	_expect(level.get_node_or_null("Architecture") == null, "Production session includes the legacy indoor laboratory.")
	_expect(level.get_node_or_null("ForestDoor") == null, "Production session includes the old biome door.")
	_expect(portable_root.get_parent() == level, "The authored laboratory was reparented at runtime.")
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
	var terrain := level.get_node("ExpeditionTerrain") as ExpeditionTerrain
	for point: Vector3 in [Vector3(-5.2, 0, -3.7), Vector3(5.2, 0, -3.7), Vector3(-5.2, 0, 2.5), Vector3(5.2, 0, 2.5), Vector3.ZERO]:
		var sample := portable_root.to_global(point)
		_expect(absf(terrain.get_height_at_global(sample) - (portable_root.global_position.y - 0.03)) < 0.01, "Laboratory footprint is not level.")
		_expect(bool(terrain.call("_is_reserved", Vector2(sample.x, sample.z))), "Trees may spawn inside the laboratory footprint.")
	_expect(portable_root.get_node_or_null("Table") != null, "Cooking equipment was not moved into the portable laboratory.")
	var dressing := portable_root.get_node_or_null("AuthoredLaboratoryDressing") as PortableLaboratoryDressing
	_expect(dressing != null, "The portable laboratory has no authored camp dressing.")
	if dressing != null:
		var model_count := 0
		for node: Node in portable_root.find_children("*", "Node3D", true, false):
			if not node.scene_file_path.is_empty():
				model_count += 1
		_expect(model_count >= 24, "The portable laboratory is missing authored model instances.")
		for model_name: String in ["FieldTent", "WeatherCanvas", "CampfirePit", "CookingTripod"]:
			_expect(dressing.get_node_or_null(model_name) != null, "Missing authored laboratory model: %s." % model_name)
	var cauldron := portable_root.get_node_or_null("Cauldron") as Node3D
	var table := portable_root.get_node_or_null("Table") as Node3D
	_expect(portable_root.get_node_or_null("ShelterProgressionVisuals/SleepingCorner") == null, "Indoor bed leaked into portable laboratory.")
	_expect(cauldron != null and cauldron.get_node_or_null("CastIronPot") != null, "The cooking vessel is still a placeholder primitive.")
	_expect(table != null and table.get_node_or_null("AuthoredWorkbench") != null, "The preparation table is still a placeholder primitive.")
	for model_path: String in ["Table/AuthoredWorkbench", "Mortar/StoneMortarBowl", "Cauldron/CastIronPot", "Bellows/AuthoredBellows", "Distiller/Retort", "AuthoredLaboratoryDressing/CampfirePit", "AuthoredLaboratoryDressing/CookingTripod"]:
		var model := portable_root.get_node_or_null(model_path)
		_expect(model != null and model.scene_file_path.begins_with("res://assets/models/laboratory/"), "Shared Blender model missing: %s" % model_path)
		if model != null:
			_expect(not model.find_children("*", "MeshInstance3D", true, false).is_empty(), "Imported model has no geometry: %s" % model_path)
	if cauldron != null and table != null:
		_expect(cauldron.position.distance_to(table.position) > 1.5, "Heat and preparation stations still overlap and compete for interaction focus.")
		var liquid := portable_root.get_node("CookingStationVisuals/ActiveLiquid") as Node3D
		var offset := liquid.position - cauldron.position
		var rest := cauldron.position
		cauldron.position.y += 0.18
		await get_tree().process_frame
		await get_tree().process_frame
		_expect((liquid.position - cauldron.position).is_equal_approx(offset), "Liquid did not follow the raised pot.")
		cauldron.position = rest
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
