extends Node

const PLAYER_SCENE := preload("res://features/player/player.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	_test_theme()
	await _test_physical_grab()
	await _test_weather()
	if _failures.is_empty():
		print("TRip physical/weather/UI test: PASS")
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		get_tree().quit(1)


func _test_theme() -> void:
	var theme := TripUITheme.build()
	_expect(theme.get_stylebox("normal", "Button") != null, "Modern UI theme has no button style.")
	_expect(theme.get_stylebox("panel", "PanelContainer") != null, "Modern UI theme has no panel style.")
	_expect(theme.get_stylebox("fill", "ProgressBar") != null, "Modern UI theme has no progress style.")


func _test_physical_grab() -> void:
	var player := PLAYER_SCENE.instantiate() as FirstPersonController
	add_child(player)
	player.set_gameplay_input_override_for_testing(true)
	var body := RigidBody3D.new()
	body.mass = 2.0
	body.position = Vector3(0, 1.58, -1.5)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 0.4, 0.4)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	await get_tree().physics_frame
	player.interactor.call("_begin_grab", body)
	player.interactor.call("_physics_process", 1.0 / 60.0)
	_expect(player.interactor.is_holding_body(), "Physical body was not grabbed.")
	_expect(body.linear_damp >= 6.9, "Grab did not engage stable spring damping.")
	player.interactor.call("_release_grabbed_body")
	_expect(not player.interactor.is_holding_body(), "Physical body did not release.")
	player.queue_free()
	body.queue_free()


func _test_weather() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.environment = Environment.new()
	world_environment.environment.fog_enabled = true
	world_environment.environment.volumetric_fog_enabled = true
	add_child(world_environment)
	var player := PLAYER_SCENE.instantiate() as FirstPersonController
	add_child(player)
	var weather := WeatherOrchestrator.new()
	add_child(weather)
	weather.setup(world_environment, player)
	weather.set_weather(WeatherOrchestrator.State.STORM, 1.0, true)
	weather.call("_process", 1.0)
	_expect(weather.state == WeatherOrchestrator.State.STORM, "Developer weather switching failed.")
	_expect(weather.wind.length() > 1.0, "Storm has no systemic wind.")
	_expect(weather.wetness > 0.0, "Storm did not begin wetting the world.")
	var precipitation := weather.get_node("LocalPrecipitation") as GPUParticles3D
	_expect(precipitation != null and precipitation.emitting, "Storm precipitation is not visible.")
	weather.developer_set(WeatherOrchestrator.State.FOG)
	_expect(world_environment.environment.fog_density > 0.0, "Fog state did not affect the environment.")
	weather.queue_free()
	player.queue_free()
	world_environment.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
