extends Node

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	ContentDB.rebuild()
	var player := (load("res://features/player/player.tscn") as PackedScene).instantiate() as FirstPersonController
	add_child(player)
	await get_tree().process_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector3.ZERO
	player.velocity = Vector3.ZERO

	var quiet_mystery := load("res://content/mysteries/bound_thread.tres") as WorldMysteryDefinition
	var quiet_poi := WorldMysteryPOI.new()
	add_child(quiet_poi)
	quiet_poi.configure(quiet_mystery, Vector3.ZERO)
	var mystery_audio := quiet_poi.get("_event_audio") as AudioStreamPlayer3D
	_expect(mystery_audio != null and mystery_audio.stream is AudioStreamOggVorbis, "World mystery is not using a recorded OGG asset.")
	var sample := GeneratedBiomeIngredient.new()
	sample.configure(&"ingredient.mooncap", &"test.reveal", Color(0.7, 0.9, 0.4), 0)
	quiet_poi.add_child(sample)
	quiet_poi.register_reveal_node(sample)
	_expect(not sample.visible, "Local reward was visible before the mystery event resolved.")
	var quiet_interactable := quiet_poi.find_child("InteractableComponent", true, false) as InteractableComponent
	quiet_interactable.complete_interaction(player)
	_expect(not bool(quiet_poi.get("_was_discovered")), "Mystery resolved immediately instead of testing its ritual rule.")
	for _step: int in 4:
		quiet_poi.call("_process", 1.0)
	_expect(bool(quiet_poi.get("_was_discovered")), "Holding still did not resolve the Altai waymark event.")
	_expect(sample.visible, "Resolving the mystery did not reveal its local ingredient reward.")

	var hunt_mystery := load("res://content/mysteries/warm_bone.tres") as WorldMysteryDefinition
	var hunt_poi := WorldMysteryPOI.new()
	add_child(hunt_poi)
	hunt_poi.configure(hunt_mystery, Vector3.ZERO)
	var hunt_interactable := hunt_poi.find_child("InteractableComponent", true, false) as InteractableComponent
	hunt_interactable.complete_interaction(player)
	player.velocity = Vector3.ZERO
	for _step: int in 3:
		hunt_poi.call("_process", 1.0)
	_expect(not bool(hunt_poi.get("_event_active")), "Standing still did not fail the Crimson keep-walking event.")
	_expect(not bool(hunt_poi.get("_was_discovered")), "Failed mystery event incorrectly granted its discovery.")

	var mystery_paths := [
		"bound_thread", "spore_sentence", "warm_bone", "frozen_hour",
		"camp_erasure", "reflection_first", "brothers_echo", "final_laboratory",
	]
	var used_rules: Dictionary[int, bool] = {}
	for file_name: String in mystery_paths:
		var definition := load("res://content/mysteries/%s.tres" % file_name) as WorldMysteryDefinition
		_expect(definition != null and not definition.event_instruction.is_empty(), "Mystery %s has no authored event instruction." % file_name)
		_expect(definition != null and not definition.failure_text.is_empty(), "Mystery %s has no authored failure consequence." % file_name)
		if definition != null:
			used_rules[int(definition.event_rule)] = true
	_expect(used_rules.size() >= 5, "World mysteries do not use the full set of distinct interaction rules.")

	quiet_poi.free()
	hunt_poi.free()
	player.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip world mystery event test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip world mystery event test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
