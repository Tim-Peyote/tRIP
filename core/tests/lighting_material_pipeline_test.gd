extends Node

var _failures: Array[String] = []


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 2841, true)
	for _frame: int in 8:
		await get_tree().process_frame
	var level := main.find_child("ExpeditionSession", true, false) as SessionController
	_expect(level != null, "Gameplay level did not load for lighting QA.")
	if level != null:
		_test_environment(level)
		_test_light_rig(level)
		_test_materials(level)
		_test_day_cycle(level)
	main.free()
	if _failures.is_empty():
		print("TRip lighting/material pipeline test: PASS")
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		get_tree().quit(1)


func _test_environment(level: SessionController) -> void:
	var controller := level.biome_visual_controller
	var environment := controller.get("_environment") as Environment
	var probe := controller.get("_reflection_probe") as ReflectionProbe
	_expect(environment != null, "Biome controller has no runtime environment.")
	if environment == null:
		return
	_expect(environment.tonemap_mode == Environment.TONE_MAPPER_AGX, "Runtime environment is not using hue-preserving AgX tone mapping.")
	_expect(environment.reflected_light_source == Environment.REFLECTION_SOURCE_SKY, "Materials do not receive sky image-based reflections.")
	controller.set_quality_preset(&"balanced")
	_expect(environment.ssr_enabled and environment.ssr_max_steps >= 32, "Balanced quality has no screen-space reflections.")
	_expect(probe != null and probe.visible and probe.update_mode == ReflectionProbe.UPDATE_ONCE, "Traveling reflection probe is missing or configured as an expensive continuous capture.")
	if probe != null:
		_expect(probe.global_position.distance_to(level.player.global_position + Vector3.UP * 2.8) < 0.1, "Reflection probe does not follow the active player volume.")
	controller.set_quality_preset(&"performance")
	_expect(not environment.ssr_enabled and probe != null and not probe.visible, "Performance quality did not disable expensive reflections.")
	controller.set_quality_preset(&"cinematic")
	_expect(environment.ssr_enabled and environment.ssr_max_steps >= 64 and environment.ssil_enabled, "Cinematic quality did not enable the complete indirect-lighting stack.")
	_expect(probe != null and probe.visible and probe.enable_shadows, "Cinematic reflection capture has no shadowed local geometry.")
	controller.set_quality_preset(&"balanced")


func _test_light_rig(level: SessionController) -> void:
	var controller := level.biome_visual_controller
	var primary := controller.get_primary_light()
	_expect(primary != null and primary.visible and primary.shadow_enabled, "The authored sun/moon key light is missing its shadows.")
	if primary != null:
		_expect(primary.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "The key light is not using four cascades for near/far landscape shadows.")
		_expect(primary.directional_shadow_max_distance >= 80.0, "Landscape shadow distance is too short for the first-person vista.")
	var shadowed_directionals := 0
	for node: Node in level.find_children("*", "DirectionalLight3D", true, false):
		var light := node as DirectionalLight3D
		if light.visible and light.shadow_enabled:
			shadowed_directionals += 1
	_expect(shadowed_directionals == 1, "More than one shadow-casting directional light washes out or contradicts the landscape.")


func _test_materials(level: SessionController) -> void:
	var terrain := level.get_node("ExpeditionTerrain") as ExpeditionTerrain
	var terrain_material := terrain.get("_terrain_material") as ShaderMaterial
	var terrain_code := terrain_material.shader.code if terrain_material != null and terrain_material.shader != null else ""
	_expect("NORMAL = normalize" in terrain_code, "Terrain material has no procedural surface normals for moving sunlight.")
	_expect("vec3 indirect_fill" not in terrain_code, "Terrain still uses shadow-cancelling constant emission.")
	var water := terrain.call("_water_material", Color(0.08, 0.32, 0.38)) as ShaderMaterial
	var water_code := water.shader.code if water != null and water.shader != null else ""
	_expect("METALLIC = 0.0" in water_code, "Water is still treated as a metallic surface.")
	_expect("SPECULAR = 0.92" in water_code and "TIME" in water_code, "Water has no responsive Fresnel highlight or animated ripples.")


func _test_day_cycle(level: SessionController) -> void:
	var primary := level.biome_visual_controller.get_primary_light()
	level.expedition_clock.set_progress(0.35)
	var day_rotation := primary.rotation if primary != null else Vector3.ZERO
	var day_energy := primary.light_energy if primary != null else 0.0
	level.expedition_clock.set_progress(0.88)
	var night_rotation := primary.rotation if primary != null else Vector3.ZERO
	var night_energy := primary.light_energy if primary != null else 0.0
	_expect(not day_rotation.is_equal_approx(night_rotation), "Day/night cycle does not move the key light or its shadows.")
	_expect(not is_equal_approx(day_energy, night_energy), "Day/night cycle does not rebalance direct lighting energy.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
