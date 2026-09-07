extends Node

var failures: PackedStringArray = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	InputBootstrap.ensure_defaults()
	var packed := load("res://world/levels/expedition_session.tscn") as PackedScene
	var session := packed.instantiate() as SessionController
	_expect(session != null, "Production session does not implement SessionController.")
	_expect(session.get_script().get_base_script() == load("res://world/levels/session_controller.gd"), "Production session inherits a prototype controller.")
	add_child(session)
	session.initialize_new_session()
	for name_value: String in ["Architecture", "ForestDoor", "ForestClearing", "ForestTrail", "DeepGrove", "RootWell", "ProceduralAmbience"]:
		_expect(session.get_node_or_null(name_value) == null, "Legacy branch in production: " + name_value)
	_expect(session.road_laboratory.get_laboratory_root().get_parent() == session, "Laboratory was reparented from another composition.")
	session.session_persistence.setup(session, session.game_loop_orchestrator, 907)
	session.player.inventory.add_item(ItemInstance.new(&"ingredient.mooncap", 1.0))
	session.road_laboratory.developer_toggle(false)
	var data := session.session_persistence.capture_save_data()
	var restored := packed.instantiate() as SessionController
	add_child(restored)
	restored.session_persistence.setup(restored, restored.game_loop_orchestrator, 908)
	restored.session_persistence.apply_save_data(data)
	_expect(restored.player.inventory.count(&"ingredient.mooncap") == 1.0, "Production inventory did not restore.")
	_expect(restored.road_laboratory.unlocked and restored.road_laboratory.manifested, "Production laboratory state did not restore.")
	_expect(restored.get_road_laboratory().get_laboratory_root().get_parent() == restored, "Restored laboratory lost scene ownership.")
	_expect(session.get_node("WorldEnvironment").environment != restored.get_node("WorldEnvironment").environment, "Session environments share mutable state.")
	session.free()
	restored.free()
	await get_tree().process_frame
	for failure: String in failures:
		push_error(failure)
	print("TRip session architecture test: " + ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
