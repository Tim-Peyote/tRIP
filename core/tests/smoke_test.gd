extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_project_contract()
	_test_content_resources()
	_test_recorded_audio_library()
	_test_recipe_resolution()
	_test_main_scene()
	if _failures.is_empty():
		print("TRip smoke test: PASS")
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		print("TRip smoke test: FAIL (%d)" % _failures.size())
		get_tree().quit(1)


func _test_project_contract() -> void:
	_expect(ProjectSettings.get_setting("application/config/name") == "TRip", "Project name is not TRip.")
	_expect(ProjectSettings.get_setting("application/run/main_scene") == "res://app/main/main.tscn", "Main scene path changed.")
	for action: StringName in [&"interact", &"inspect", &"move_forward", &"jump", &"inventory", &"journal", &"map", &"pause", &"toggle_view", &"look_left", &"look_right", &"look_up", &"look_down"]:
		_expect(InputMap.has_action(action), "Missing input action '%s'." % action)
	for bus_name: StringName in [&"Master", &"Music", &"UI", &"PlayerFoley", &"World", &"Ambience", &"Creatures", &"Interactions", &"Voice", &"Perception"]:
		_expect(AudioServer.get_bus_index(bus_name) >= 0, "Missing audio bus '%s'." % bus_name)


func _test_content_resources() -> void:
	var paths := [
		"res://content/ingredients/mooncap.tres",
		"res://content/effects/spore_sight.tres",
		"res://content/items/spore_sight_brew.tres",
		"res://content/recipes/spore_sight_brew.tres",
	]
	var ids: Dictionary[StringName, bool] = {}
	for path: String in paths:
		var definition := load(path) as ContentDefinition
		_expect(definition != null, "Could not load ContentDefinition: %s" % path)
		if definition == null:
			continue
		_expect(definition.validate().is_empty(), "Definition failed validation: %s" % path)
		_expect(not ids.has(definition.id), "Duplicate test content id: %s" % definition.id)
		ids[definition.id] = true


func _test_recorded_audio_library() -> void:
	var paths := [
		"res://assets/third_party/open_game_art_audio/forest_ambience.mp3",
		"res://assets/third_party/open_game_art_audio/creepy_forest.ogg",
		"res://assets/third_party/open_game_art_audio/dark_cavern.ogg",
		"res://assets/third_party/open_game_art_audio/dungeon_ambience.ogg",
		"res://assets/third_party/open_game_art_audio/rain_long.ogg",
		"res://assets/third_party/open_game_art_audio/wind_soft.ogg",
		"res://assets/third_party/open_game_art_audio/wind_strong.ogg",
		"res://assets/third_party/open_game_art_audio/wind_gust.ogg",
		"res://assets/third_party/open_game_art_audio/fire_loop.ogg",
		"res://assets/third_party/open_game_art_audio/thunderclap.wav",
	]
	for path: String in paths:
		var audio_stream := load(path) as AudioStream
		_expect(audio_stream != null, "Recorded audio failed to import: %s" % path)
		if audio_stream != null:
			_expect(audio_stream.get_length() > 0.05, "Recorded audio is empty: %s" % path)


func _test_recipe_resolution() -> void:
	var recipe := load("res://content/recipes/spore_sight_brew.tres") as RecipeDefinition
	if recipe == null:
		_expect(false, "Recipe fixture did not load.")
		return
	var process := CookingProcess.new()
	var grind := CookingProcessEvent.new(&"grind", &"ingredient.mooncap", 1.0, 20.0, 8.0)
	grind.ingredient_tags.assign([&"fungus", &"perception", &"part_cap"])
	process.append_event(grind)
	var heat := CookingProcessEvent.new(&"heat", &"ingredient.mooncap", 1.0, 80.0, 24.0)
	heat.ingredient_tags.assign([&"fungus", &"perception"])
	process.append_event(heat)
	var result := RecipeResolver.new().resolve(process, recipe)
	_expect(result.quality == RecipeResolution.Quality.PURE, "Perfect recipe did not resolve to PURE.")
	_expect(result.result_item_id == &"item.spore_sight_brew", "Recipe returned the wrong item id.")


func _test_main_scene() -> void:
	var packed := load("res://app/main/main.tscn") as PackedScene
	_expect(packed != null, "Main scene failed to load.")
	if packed == null:
		return
	var instance := packed.instantiate()
	_expect(instance is TripMain, "Main scene root is not TripMain.")
	instance.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
