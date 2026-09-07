extends Node

const LANDFORM = preload("res://world/terrain/altai_landform.gd")

func _ready() -> void:
	for seed_value in [618, 1701, 9321]:
		for z in range(60, 750, 5):
			var x: float = LANDFORM.river_x(z, seed_value)
			var bed: float = LANDFORM.carve_river(24.0, Vector2(x, z), seed_value)
			assert(bed < LANDFORM.water_height(z), "Dry river bed")
			assert(LANDFORM.water_height(z + 1) > LANDFORM.water_height(z), "Uphill drainage")
			assert(LANDFORM.relief(Vector2(x + 175, z), seed_value) > LANDFORM.relief(Vector2(x, z), seed_value), "Missing valley hierarchy")
	print("Altai landform contracts: PASS")
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 1701, true)
	await get_tree().process_frame
	var level := main.find_child("ExpeditionSession", true, false) as SessionController
	var terrain := level.get_node("ExpeditionTerrain") as ExpeditionTerrain
	level.get_weather().automatic = false
	level.get_weather().set_weather(WeatherOrchestrator.State.CLEAR, 0.0, true)
	var point := Vector3(LANDFORM.river_x(210.0, 1701) - 20.0, 0.0, 210.0)
	point.y = terrain.get_height_at_global(point) + 1.0
	terrain.ensure_area_at(point)
	level.player.global_position = point
	level.player.look_at(Vector3(LANDFORM.river_x(245.0, 1701), 0.0, 245.0))
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	for frame in 45:
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png("/tmp/trip_altai_river.png")
	get_tree().quit()
