class_name PlayerAvatarAnimator
extends Node3D

@export var avatar_scale: float = 0.31
@export var transition_time: float = 0.16

var _controller: FirstPersonController
var _animation_player: AnimationPlayer
var _current_animation: StringName
var _jump_locked: bool = false
var _third_person_visible: bool = false

const AVATAR_MATERIAL = preload("res://features/player/player_avatar_material.tres")

const ANIMATIONS := {
	&"idle": &"Human Armature|Idle",
	&"walk": &"Human Armature|Walk",
	&"run": &"Human Armature|Run",
	&"jump": &"Human Armature|Jump",
	&"work": &"Human Armature|Working",
}


func _ready() -> void:
	_controller = get_parent() as FirstPersonController
	scale = Vector3.ONE * avatar_scale
	_animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_override = AVATAR_MATERIAL
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		mesh.visibility_range_end = 45.0
	if _animation_player != null:
		_animation_player.animation_finished.connect(_on_animation_finished)
		_play(&"idle", 1.0)


func set_third_person_visible(value: bool) -> void:
	_third_person_visible = value
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if value
			else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		)


func is_third_person_visible() -> bool:
	return _third_person_visible


func _process(_delta: float) -> void:
	if _controller == null or _animation_player == null or _jump_locked:
		return
	if not _controller.is_grounded():
		_play(&"jump", 1.0)
		_jump_locked = true
		return
	var speed := _controller.get_planar_speed()
	if speed < 0.12:
		_play(&"idle", 1.0)
	elif _controller.is_sprinting():
		_play(&"run", clampf(speed / _controller.sprint_speed, 0.75, 1.25))
	else:
		_play(&"walk", clampf(speed / _controller.walk_speed, 0.55, 1.3))


func play_work_action() -> void:
	_jump_locked = false
	_play(&"work", 1.0, true)


func get_current_state() -> StringName:
	return _current_animation


func _play(state: StringName, speed: float, force: bool = false) -> void:
	var animation: StringName = ANIMATIONS.get(state, ANIMATIONS[&"idle"])
	if not force and _current_animation == state:
		_animation_player.speed_scale = speed
		return
	if not _animation_player.has_animation(animation):
		return
	_current_animation = state
	_animation_player.play(animation, transition_time, speed)


func _on_animation_finished(_animation: StringName) -> void:
	if _current_animation in [&"jump", &"work"]:
		_jump_locked = false
		_current_animation = &""
