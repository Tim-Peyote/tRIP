extends Node3D

func _ready() -> void:
	var lab := (load("res://features/road_laboratory/portable_laboratory.tscn") as PackedScene).instantiate()
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame
	var cooking := CookingOrchestrator.new()
	add_child(cooking)
	var visuals := lab.get_node("CookingStationVisuals") as CookingStationVisuals
	visuals.setup(cooking)
	var bellows := lab.get_node("Bellows/AuthoredBellows") as Node3D
	var body := lab.get_node("Bellows") as Node3D
	var rest := bellows.scale
	var body_rest := body.transform
	cooking.add_water()
	cooking.vessel.add_ingredient(&"ingredient.mooncap", 1.0)
	cooking.cycle_heat()
	assert(cooking.pump_bellows())
	await get_tree().create_timer(0.12).timeout
	assert(bellows.scale.z < rest.z * 0.9)
	assert(body.transform.is_equal_approx(body_rest))
	assert(cooking.stir_vessel())
	await get_tree().create_timer(0.65).timeout
	assert(bellows.scale.is_equal_approx(rest), "Stirring interrupted bellows recovery")
	cooking.reset_process()
	assert(not visuals.active_liquid.visible and not visuals.steam.visible)
	lab.queue_free()
	cooking.queue_free()
	await get_tree().process_frame
	print("TRip laboratory motion test: PASS")
	get_tree().quit()
