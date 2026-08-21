extends Node

const AVATAR_PATH := "res://assets/third_party/quaternius_animated_human/Animated Human.fbx"

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(AVATAR_PATH) as PackedScene
	_expect(packed != null, "CC0 humanoid failed to import as PackedScene.")
	if packed != null:
		var avatar := packed.instantiate()
		add_child(avatar)
		var skeletons := avatar.find_children("*", "Skeleton3D", true, false)
		var meshes := avatar.find_children("*", "MeshInstance3D", true, false)
		var players := avatar.find_children("*", "AnimationPlayer", true, false)
		_expect(not skeletons.is_empty(), "Imported humanoid has no Skeleton3D.")
		_expect(not players.is_empty(), "Imported humanoid has no AnimationPlayer.")
		if not meshes.is_empty(): print("TRip avatar AABB: %s" % (meshes[0] as MeshInstance3D).get_aabb())
		if not players.is_empty():
			var animation_player := players[0] as AnimationPlayer
			var names := animation_player.get_animation_list()
			print("TRip avatar animations: %s" % ", ".join(names))
			_expect(names.size() >= 6, "Imported humanoid has fewer than six animation clips.")
		avatar.queue_free()
		await get_tree().process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip player avatar import test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures: push_error(failure)
	print("TRip player avatar import test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
