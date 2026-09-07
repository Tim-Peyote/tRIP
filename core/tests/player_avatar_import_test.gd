extends Node

const AVATAR_PATH := "res://assets/models/actors/geo_researcher.glb"

var _failures := PackedStringArray()


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(AVATAR_PATH) as PackedScene
	_expect(packed != null, "GEO humanoid failed to import as PackedScene.")
	if packed != null:
		var avatar := packed.instantiate()
		add_child(avatar)
		var skeletons := avatar.find_children("*", "Skeleton3D", true, false)
		var meshes := avatar.find_children("*", "MeshInstance3D", true, false)
		var players := avatar.find_children("*", "AnimationPlayer", true, false)
		_expect(not skeletons.is_empty(), "Imported humanoid has no Skeleton3D.")
		if not skeletons.is_empty():
			var skeleton := skeletons[0] as Skeleton3D
			_expect(skeleton.get_bone_count() == 65, "Expected the downloaded 65-bone Mixamo rig.")
			_expect(skeleton.find_bone("mixamorig_RightHandIndex3") >= 0, "Mixamo finger chain is missing.")
		_expect(not players.is_empty(), "Imported humanoid has no AnimationPlayer.")
		if not meshes.is_empty(): print("TRip avatar AABB: %s" % (meshes[0] as MeshInstance3D).get_aabb())
		if not players.is_empty():
			var animation_player := players[0] as AnimationPlayer
			var names := animation_player.get_animation_list()
			print("TRip avatar animations: %s" % ", ".join(names))
			_expect(names.size() >= 6, "Imported humanoid has fewer than six animation clips.")
			for clip: String in ["Idle", "Walk", "Run", "Jump", "Working", "Seated", "CrouchIdle", "CrouchWalk"]:
				var clip_name := "Human Armature|" + clip
				_expect(animation_player.has_animation(clip_name), "Missing clip: " + clip_name)
				if animation_player.has_animation(clip_name):
					var animation := animation_player.get_animation(clip_name)
					_expect(animation.get_track_count() > 0 and animation.length > 0.1, "Empty clip: " + clip_name)
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
