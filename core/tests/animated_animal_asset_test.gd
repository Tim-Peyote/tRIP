extends Node

const ANIMAL_SCENES: Array[PackedScene] = [
	preload("res://assets/third_party/quaternius_animated_animals/Deer.fbx"),
	preload("res://assets/third_party/quaternius_animated_animals/Stag.fbx"),
	preload("res://assets/third_party/quaternius_animated_animals/Wolf.fbx"),
]


func _ready() -> void:
	var failures := PackedStringArray()
	for scene: PackedScene in ANIMAL_SCENES:
		var instance := scene.instantiate()
		add_child(instance)
		var skeletons := instance.find_children("*", "Skeleton3D", true, false)
		var skeleton := skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
		var animation_player := instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if skeleton == null:
			failures.append("%s has no Skeleton3D" % scene.resource_path)
		if animation_player == null:
			failures.append("%s has no AnimationPlayer" % scene.resource_path)
		else:
			var animations := animation_player.get_animation_list()
			print("%s animations: %s" % [scene.resource_path.get_file(), ", ".join(animations)])
			if animations.size() < 8:
				failures.append("%s exposes fewer than eight clips" % scene.resource_path)
		instance.queue_free()
	if failures.is_empty():
		print("TRip animated animal asset test: PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("TRip animated animal asset test: FAIL (%d)" % failures.size())
		get_tree().quit(1)
