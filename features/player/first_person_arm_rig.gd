class_name FirstPersonArmRig
extends Node3D

@export_range(0.0, 1.4, 0.05) var grip_amount: float = 0.32
@export_range(-1.2, 1.2, 0.05) var tool_wrist_twist: float = 0.0

var _skeleton: Skeleton3D
var _physical_interaction_active: bool = false


func _ready() -> void:
	_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		# Preserve the GEO body's skin and garment materials in both views.
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_physical_interaction_pose(false)


func _apply_idle_grip() -> void:
	if _skeleton == null:
		return
	var wrist := _skeleton.find_bone("mixamorig_RightHand")
	if wrist >= 0:
		_skeleton.set_bone_pose_rotation(wrist, Quaternion.from_euler(Vector3(0.0, tool_wrist_twist, 0.0)))


func set_physical_interaction_pose(active: bool) -> void:
	_physical_interaction_active = active
	for node in find_children("GEO_Arm_L*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).visible = active
	_apply_idle_grip()
