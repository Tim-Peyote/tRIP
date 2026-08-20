extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	InputBootstrap.ensure_defaults()
	ContentDB.rebuild()
	var player := (load("res://features/player/player.tscn") as PackedScene).instantiate() as FirstPersonController
	var plant := (load("res://features/ingredients/mooncap_world.tscn") as PackedScene).instantiate() as HarvestableIngredient
	add_child(player)
	add_child(plant)
	await get_tree().process_frame
	var component := plant.interactable
	_expect(plant.get_selected_part() == &"cap", "Mooncap does not default to cap selection.")
	_expect(component.can_interact(player), "Equipped knife cannot cut cap.")
	player.toolbelt.toggle_active_tool()
	_expect(not component.can_interact(player), "Bare hands can cut a clean cap.")
	component.request_alternative(player)
	component.request_alternative(player)
	_expect(plant.get_selected_part() == &"whole", "Alternative action did not cycle to whole plant.")
	_expect(component.can_interact(player), "Whole plant cannot be pulled with bare hands.")
	component.complete_interaction(player)
	await get_tree().process_frame
	var harvested := player.inventory.items[0]
	_expect(harvested.processing_state.get(&"part") == &"whole", "Harvested runtime item lost selected part.")
	_expect(is_equal_approx(harvested.quality, 0.55), "Bare-hand harvest quality is incorrect.")
	var recipe := load("res://content/recipes/spore_sight_brew.tres") as RecipeDefinition
	var process := CookingProcess.new()
	var grind := CookingProcessEvent.new(&"grind", &"ingredient.mooncap", 1.0, 20.0, 8.0)
	grind.ingredient_tags.assign([&"fungus", &"perception", &"part_whole"])
	grind.source_quality = harvested.quality
	process.append_event(grind)
	var heat := CookingProcessEvent.new(&"heat", &"ingredient.mooncap", 1.0, 80.0, 24.0)
	heat.ingredient_tags.assign([&"fungus", &"perception"])
	process.append_event(heat)
	var resolution := RecipeResolver.new().resolve(process, recipe)
	_expect(resolution.quality == RecipeResolution.Quality.UNSTABLE, "Damaged whole mushroom did not degrade recipe quality.")
	player.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip harvest quality test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip harvest quality test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)

