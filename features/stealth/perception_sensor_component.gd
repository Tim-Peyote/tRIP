class_name PerceptionSensorComponent
extends Node3D

signal suspicion_changed(value: float)
signal target_detected(target: Node3D)
signal target_lost
signal noise_perceived(event: GameplayNoiseEvent)

@export_range(1.0, 40.0, 0.5, "suffix:m") var vision_range: float = 11.0
@export_range(10.0, 180.0, 1.0, "suffix:°") var vision_angle: float = 78.0
@export_range(0.05, 3.0, 0.05) var suspicion_gain: float = 0.72
@export_range(0.05, 3.0, 0.05) var suspicion_decay: float = 0.24
@export var sight_collision_mask: int = 3

var target: Node3D
var suspicion: float = 0.0
var can_see_target: bool = false


func setup_target(value: Node3D) -> void:
	target = value


func _physics_process(delta: float) -> void:
	evaluate_visibility(delta)


func evaluate_visibility(delta: float) -> bool:
	var visible := _has_line_of_sight()
	var previous := suspicion
	if visible:
		var exposure := 1.0
		if target.has_method("get_stealth_exposure"):
			exposure = float(target.call("get_stealth_exposure"))
		suspicion = clampf(suspicion + suspicion_gain * exposure * delta, 0.0, 1.0)
	else:
		suspicion = clampf(suspicion - suspicion_decay * delta, 0.0, 1.0)
	if not is_equal_approx(previous, suspicion):
		suspicion_changed.emit(suspicion)
	if visible and not can_see_target:
		can_see_target = true
		target_detected.emit(target)
	elif not visible and can_see_target:
		can_see_target = false
		target_lost.emit()
	return visible


func receive_noise(event: GameplayNoiseEvent) -> void:
	if event == null or global_position.distance_to(event.origin) > event.radius:
		return
	var previous := suspicion
	suspicion = maxf(suspicion, clampf(event.intensity * 0.72, 0.0, 0.95))
	if not is_equal_approx(previous, suspicion):
		suspicion_changed.emit(suspicion)
	noise_perceived.emit(event)


func _has_line_of_sight() -> bool:
	if target == null or not is_instance_valid(target) or not is_inside_tree():
		return false
	var target_point := target.global_position + Vector3.UP * 1.05
	var offset := target_point - global_position
	var distance := offset.length()
	var exposure := 1.0
	if target.has_method("get_stealth_exposure"):
		exposure = float(target.call("get_stealth_exposure"))
	if distance > vision_range * lerpf(0.55, 1.0, exposure):
		return false
	var forward := -global_basis.z.normalized()
	if forward.dot(offset.normalized()) < cos(deg_to_rad(vision_angle * 0.5)):
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position, target_point, sight_collision_mask)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.get("collider") == target
