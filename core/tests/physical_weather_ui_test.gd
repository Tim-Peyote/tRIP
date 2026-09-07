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
	player.free()
	body.free()


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
	var rain_audio := weather.get_node("WeatherRig/RecordedRain") as AudioStreamPlayer
	var wind_audio := weather.get_node("WeatherRig/RecordedWind") as AudioStreamPlayer
	var thunder_audio := weather.get_node("WeatherRig/SpatialThunder") as AudioStreamPlayer3D
	_expect(not rain_audio.playing, "Clear weather started the rain loop during setup.")
	_expect(thunder_audio.stream is AudioStreamWAV and (thunder_audio.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED, "Thunder one-shot is configured as a loop.")
	weather.set_weather(WeatherOrchestrator.State.STORM, 1.0, true)
	weather.call("_process", 1.0)
	_expect(weather.state == WeatherOrchestrator.State.STORM, "Developer weather switching failed.")
	_expect(weather.wind.length() > 1.0, "Storm has no systemic wind.")
	_expect(weather.wetness > 0.0, "Storm did not begin wetting the world.")
	var precipitation := weather.get_node("WeatherRig/LocalPrecipitation") as GPUParticles3D
	var depth_precipitation := weather.get_node("WeatherRig/WeatherDepthLayer") as GPUParticles3D
	_expect(precipitation != null and precipitation.emitting, "Storm precipitation is not visible.")
	_expect(depth_precipitation != null and depth_precipitation.emitting, "Storm has no distant spatial precipitation layer.")
	_expect(precipitation.draw_pass_1 is SphereMesh, "Storm still renders precipitation as screen-facing stripe quads.")
	_expect(depth_precipitation.draw_pass_1 is SphereMesh and depth_precipitation.amount < precipitation.amount, "Distant weather depth is not a bounded low-cost particle layer.")
	_expect(world_environment.environment.adjustment_brightness < 0.9, "Storm does not lower the global atmosphere exposure.")
	_expect(world_environment.environment.fog_aerial_perspective > 0.7, "Storm has no aerial perspective depth.")
	var terrain := ExpeditionTerrain.new()
	add_child(terrain)
	weather.set("_terrain", terrain)
	weather.state_changed.connect(terrain.set_weather_state)
	player.global_position = Vector3(float(terrain.call("_route_center_x", 240.0)), terrain.get_height_at_global(Vector3(0.0, 0.0, 240.0)), 240.0)
	weather.call("_sample_local_context", true)
	var valley_context := weather.get_local_context()
	_expect(not bool(valley_context.get("can_snow", true)), "Low taiga valley incorrectly allows local snowfall.")
	weather.set_weather(WeatherOrchestrator.State.STORM, 0.8, true)
	var sheltered_storm_strength := weather.get_local_intensity()
	terrain.set_weather_wetness(weather.wetness)
	var terrain_material := terrain.get("_terrain_material") as ShaderMaterial
	_expect(float(terrain_material.get_shader_parameter(&"weather_wetness")) > 0.0, "Systemic rain wetness does not reach the terrain material.")
	_expect(rain_audio.playing and wind_audio.playing and wind_audio.stream == WeatherOrchestrator.WIND_STRONG, "Storm did not start its recorded rain and strong-wind layers.")
	weather.developer_set(WeatherOrchestrator.State.FOG)
	weather.call("_update_audio", 10.0)
	_expect(world_environment.environment.fog_density > 0.0, "Fog state did not affect the environment.")
	_expect(not rain_audio.playing and wind_audio.stream == WeatherOrchestrator.WIND_SOFT, "Fog retained the previous storm audio layers.")
	weather.developer_resume_automatic()
	weather.set_weather(WeatherOrchestrator.State.SNOW, 0.8, true)
	weather.call("_sample_local_context", true)
	_expect(weather.state != WeatherOrchestrator.State.SNOW, "Snow continued falling in a low taiga valley instead of resolving into rain or fog.")
	player.global_position = Vector3(360.0, terrain.get_height_at_global(Vector3(360.0, 0.0, 340.0)), 340.0)
	weather.call("_sample_local_context", true)
	weather.set_weather(WeatherOrchestrator.State.STORM, 0.8, true)
	var exposed_storm_strength := weather.get_local_intensity()
	_expect(exposed_storm_strength > sheltered_storm_strength, "The exposed highland does not intensify the same storm front relative to the sheltered valley.")
	weather.set_weather(WeatherOrchestrator.State.SNOW, 0.8, true)
	_expect(weather.state == WeatherOrchestrator.State.SNOW, "Exposed taiga highland rejected locally valid snowfall.")
	_expect(float(terrain_material.get_shader_parameter(&"weather_snow")) > 0.5, "Local snowfall does not accumulate visually on exposed terrain.")
	terrain.free()
	weather.set_ecology_family(BiomeContentPack.EcologyFamily.GLACIAL_CIRQUE)
	var glacial_weights := weather.get_weather_weights()
	_expect(float(glacial_weights[WeatherOrchestrator.State.SNOW]) > float(glacial_weights[WeatherOrchestrator.State.DRIZZLE]), "Glacial biome does not favour snow over rain.")
	weather.set_ecology_family(BiomeContentPack.EcologyFamily.MIRROR_WETLAND)
	var wetland_weights := weather.get_weather_weights()
	_expect(float(wetland_weights[WeatherOrchestrator.State.DRIZZLE]) > float(wetland_weights[WeatherOrchestrator.State.SNOW]), "Wetland weather does not favour rain over snow.")
	weather.set_weather(WeatherOrchestrator.State.SNOW, 0.8, true)
	weather.set_ecology_family(BiomeContentPack.EcologyFamily.MIRROR_WETLAND)
	_expect(weather.state == WeatherOrchestrator.State.DRIZZLE, "Incompatible snow leaked from the previous biome into the mirror wetland.")
	weather.free()
	player.free()
	world_environment.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
