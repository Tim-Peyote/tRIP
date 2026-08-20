extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	InputBootstrap.ensure_defaults()
	ContentDB.rebuild()
	var packed := load("res://world/levels/shelter/shelter_level.tscn") as PackedScene
	_expect(packed != null, "Shelter scene failed to load.")
	if packed == null:
		_finish()
		return
	var level := packed.instantiate() as ShelterLevel
	add_child(level)
	var player := level.get_player()
	_expect(player != null, "Shelter has no player.")
	if player == null:
		_finish()
		return
	player.global_position = Vector3(0.0, 0.12, 0.1)
	player.camera_rig.rotation.x = -0.08
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.interactor.force_raycast_update()
	var component := _find_interactable(player.interactor.get_collider() as Node)
	_expect(component != null, "Player ray did not acquire the mooncap interaction.")
	if component != null:
		_expect(component.get_prompt(player).contains("Лунная шляпка"), "Mooncap prompt is not data-driven.")
		_expect(String(component.get_inspection().get("description", "")).contains("серебристые споры"), "Mooncap inspection is not data-driven.")
		_expect(component.begin_interaction(player), "Mooncap interaction could not start.")
		component.complete_interaction(player)
		await get_tree().process_frame
		_expect(player.inventory.count(&"ingredient.mooncap") == 1.0, "Collected mooncap did not reach inventory.")
		var harvested := player.inventory.items[0]
		_expect(harvested.processing_state.get(&"part") == &"cap", "Default harvest did not cut the cap.")
		_expect(harvested.quality > 0.9, "Knife harvest quality is unexpectedly low.")
	var forest_door := level.find_child("ForestDoor", true, false) as SimplePortal
	_expect(forest_door != null, "Shelter has no forest portal.")
	if forest_door != null:
		forest_door.interactable.complete_interaction(player)
		_expect(player.global_position.distance_to(Vector3(0, 0.12, 8.2)) < 0.01, "Forest portal did not move player to clearing.")
	_expect(level.find_child("ForestClearing", true, false) != null, "Forest clearing chunk is missing.")
	level.queue_free()
	await get_tree().process_frame
	_finish()


func _find_interactable(collider: Node) -> InteractableComponent:
	if collider == null:
		return null
	for child: Node in collider.get_children():
		if child is InteractableComponent:
			return child as InteractableComponent
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip gameplay test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip gameplay test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
