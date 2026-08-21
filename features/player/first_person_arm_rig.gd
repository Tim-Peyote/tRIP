class_name FirstPersonArmRig
extends Node3D

@export_range(0.0, 1.4, 0.05) var grip_amount: float = 1.2

var _skeleton: Skeleton3D


func _ready() -> void:
	_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	_apply_idle_grip()


func _apply_idle_grip() -> void:
	if _skeleton == null:
		return
	for side: String in ["r", "l"]:
		var direction := -1.0 if side == "r" else 1.0
		for finger: String in ["pinky", "ring", "middle", "index"]:
			for segment: int in [1, 2, 3]:
				_pose_bone("finger_%s%d.%s" % [finger, segment, side], Vector3(0.0, 0.0, grip_amount * direction))
		for segment: int in [1, 2, 3]:
			_pose_bone("finger_thumb%d.%s" % [segment, side], Vector3(0.0, grip_amount * 0.18 * direction, grip_amount * 0.62 * direction))


func _pose_bone(bone_name: String, rotation_value: Vector3) -> void:
	var index := _skeleton.find_bone(bone_name)
	if index >= 0:
		_skeleton.set_bone_pose_rotation(index, Quaternion.from_euler(rotation_value))
