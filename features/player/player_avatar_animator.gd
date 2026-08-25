class_name PlayerAvatarAnimator
extends Node3D

@export var avatar_scale: float = 0.31
@export var transition_time: float = 0.16
@export_range(1.0, 20.0, 0.5) var turn_speed: float = 10.0

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

const LOOPING_STATES: Array[StringName] = [&"idle", &"walk", &"run"]


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
		_configure_animation_loops()
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


func _process(delta: float) -> void:
	if _controller == null or _animation_player == null or _jump_locked:
		return
	_update_movement_facing(delta)
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


func _update_movement_facing(delta: float) -> void:
	var planar_velocity := Vector3(_controller.velocity.x, 0.0, _controller.velocity.z)
	if planar_velocity.length_squared() < 0.04:
		return
	# The Quaternius FBX is authored facing local +Z. Work in controller-local
	# space so the visible body follows actual travel instead of remaining glued
	# to camera yaw (which made strafing/reversing look like moonwalking).
	var local_direction := (_controller.global_basis.inverse() * planar_velocity).normalized()
	var target_yaw := atan2(local_direction.x, local_direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * turn_speed, 0.0, 1.0))


func play_work_action() -> void:
	_jump_locked = false
	_play(&"work", 1.0, true)


func get_current_state() -> StringName:
	return _current_animation


func _play(state: StringName, speed: float, force: bool = false) -> void:
	var animation: StringName = ANIMATIONS.get(state, ANIMATIONS[&"idle"])
	if not force and _current_animation == state:
		_animation_player.speed_scale = speed
		# Imported animation metadata is not guaranteed to preserve looping. If a
		# locomotion clip ever reaches its end, the state machine still says
		# "walk"/"run" and the old implementation left the moving avatar frozen.
		if _animation_player.is_playing() and _animation_player.current_animation == animation:
			return
	if not _animation_player.has_animation(animation):
		return
	_current_animation = state
	_animation_player.play(animation, transition_time, speed)


func _configure_animation_loops() -> void:
	for state: StringName in LOOPING_STATES:
		var animation_name: StringName = ANIMATIONS[state]
		if not _animation_player.has_animation(animation_name):
			continue
		var animation := _animation_player.get_animation(animation_name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR


func _on_animation_finished(_animation: StringName) -> void:
	if _current_animation in [&"jump", &"work"]:
		_jump_locked = false
		_current_animation = &""
	elif _current_animation in LOOPING_STATES:
		# Defensive fallback for importer/runtime changes: locomotion must never
		# finish into a static pose while the controller is still moving.
		var state := _current_animation
		_current_animation = &""
		_play(state, _animation_player.speed_scale)
