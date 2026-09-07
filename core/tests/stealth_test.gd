extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	InputBootstrap.ensure_defaults()
	ContentDB.rebuild()
	var level := (load("res://core/tests/fixtures/legacy_expedition_fixture.tscn") as PackedScene).instantiate() as LegacyExpeditionFixture
	add_child(level)
	await get_tree().physics_frame
	var player := level.player
	player.set_gameplay_input_override_for_testing(true)
	var listener := level.forest_clearing.listener
	listener.movement_speed = 0.0
	player.global_position = listener.global_position + Vector3(0, -0.55, -3.0)
	listener.look_at(player.global_position + Vector3.UP * 1.05, Vector3.UP)
	await get_tree().physics_frame
	listener.sensor.suspicion = 0.0
	var visible := listener.sensor.evaluate_visibility(2.2)
	_expect(visible, "Listener cannot see an unobstructed nearby player.")
	_expect(listener.sensor.suspicion >= 0.99, "Direct visibility did not fill suspicion.")
	_expect(listener.state == ListenerCreature.State.CHASE, "Full suspicion did not start chase state.")

	var standing_exposure := player.get_stealth_exposure()
	Input.action_press(&"crouch")
	await get_tree().physics_frame
	var crouched_exposure := player.get_stealth_exposure()
	Input.action_release(&"crouch")
	_expect(crouched_exposure < standing_exposure, "Crouching does not reduce visibility exposure.")

	listener.sensor.suspicion = 0.0
	listener.state = ListenerCreature.State.IDLE
	var before_count := player.distraction_thrower.remaining
	var projectile := player.distraction_thrower.throw(listener.global_position + Vector3(0, 1.0, -2.0), Vector3.FORWARD)
	_expect(projectile != null, "Distraction projectile was not created.")
	_expect(player.distraction_thrower.remaining == before_count - 1, "Throw did not consume a stone.")
	projectile.global_position = listener.global_position + Vector3(1.0, 0.0, 0.0)
	projectile.call("_impact")
	_expect(listener.sensor.suspicion > 0.6, "Stone impact did not raise creature suspicion.")
	_expect(listener.state == ListenerCreature.State.ALERT, "Loud stone impact did not create alert state.")
	level.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip stealth test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip stealth test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
