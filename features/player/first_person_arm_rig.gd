class_name FirstPersonArmRig
extends Node3D

const ARM_ALBEDO = preload("res://assets/third_party/wrad_arms/arm_albedo_pale.png")

@export_range(0.0, 1.4, 0.05) var grip_amount: float = 1.2
@export_range(-1.2, 1.2, 0.05) var tool_wrist_twist: float = 0.55

var _skeleton: Skeleton3D


func _ready() -> void:
	_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	_apply_viewmodel_material()
	_apply_idle_grip()


func _apply_viewmodel_material() -> void:
	var arm_mesh := find_child("arms_mesh", true, false) as MeshInstance3D
	if arm_mesh == null:
		return
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D arm_albedo : source_color;
void fragment() {
	vec3 base = texture(arm_albedo, UV).rgb;
	float form = 0.76 + 0.18 * clamp(NORMAL.y * 0.5 + 0.5, 0.0, 1.0);
	ALBEDO = base * form;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"arm_albedo", ARM_ALBEDO)
	arm_mesh.material_override = material
	arm_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _apply_idle_grip() -> void:
	if _skeleton == null:
		return
	_pose_bone("wrist.r", Vector3(0.0, tool_wrist_twist, 0.0))
	for side: String in ["r", "l"]:
		var direction := -1.0 if side == "r" else 1.0
		var amount := grip_amount if side == "r" else grip_amount * 0.3
		for finger: String in ["pinky", "ring", "middle", "index"]:
			for segment: int in [1, 2, 3]:
				_pose_bone("finger_%s%d.%s" % [finger, segment, side], Vector3(0.0, 0.0, amount * direction))
		for segment: int in [1, 2, 3]:
			_pose_bone("finger_thumb%d.%s" % [segment, side], Vector3(0.0, amount * 0.18 * direction, amount * 0.62 * direction))


func _pose_bone(bone_name: String, rotation_value: Vector3) -> void:
	var index := _skeleton.find_bone(bone_name)
	if index >= 0:
		_skeleton.set_bone_pose_rotation(index, Quaternion.from_euler(rotation_value))
