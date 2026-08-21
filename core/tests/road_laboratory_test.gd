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
	await get_tree().create_timer(1.5).timeout
	_expect(laboratory.unlocked and laboratory.manifested, "The ritual did not manifest the road laboratory.")
	_expect(portable_root.visible, "The manifested laboratory remained invisible.")
	_expect(portable_root.get_node_or_null("Table") != null, "Cooking equipment was not moved into the portable laboratory.")
	var save_data := laboratory.to_save_data()
	_expect(bool(save_data.get("unlocked", false)), "Ritual unlock state was not serializable.")
	_expect((save_data.get("laboratory_position", []) as Array).size() == 3, "Laboratory position was not serializable.")
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
