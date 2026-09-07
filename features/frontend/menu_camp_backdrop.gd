class_name MenuCampBackdrop
extends Node3D

var _camera: Camera3D
var _fire_light: OmniLight3D
var _flames: Array[MeshInstance3D] = []
var _flame_rest: Array[Transform3D] = []
var _upgrade_root: Node3D
var _time: float = 0.0
var _laboratory_level: int = 0
var _camera_rest: Vector3
var _fire_energy: float
@export_range(0.0, 1.0) var parallax_amount: float = 0.28
@export_range(0.0, 1.0) var flicker_amount: float = 0.12


func _ready() -> void:
	_apply_natural_surfaces()
	preload("res://presentation/materials/laboratory_surface_library.gd").apply_to(self)
	_camera = $Camera
	_fire_light = $FireLight
	_upgrade_root = $RoadLaboratory/PersistentUpgrades
	var actor_animation := $SeatedResearcher/GEOBody.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if actor_animation != null and actor_animation.has_animation(&"Human Armature|Seated"):
		actor_animation.get_animation(&"Human Armature|Seated").loop_mode = Animation.LOOP_LINEAR
		actor_animation.play(&"Human Armature|Seated")
	for index: int in 3:
		_flames.append(get_node("Flame%d" % index) as MeshInstance3D)
		_flames[index].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flame_rest.append(_flames[index].transform)
	_camera_rest = _camera.position
	_fire_energy = _fire_light.light_energy
	refresh_from_save()
	set_process(true)


func _apply_natural_surfaces() -> void:
	# Shared materials keep the front end consistent with the ordinary-world taiga.
	var bark := preload("res://presentation/materials/taiga_bark.tres")
	var granite := preload("res://presentation/materials/taiga_granite.tres")
	var soil := preload("res://presentation/materials/taiga_soil.tres")
	for node in $CedarClearing.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface)
			if original == null:
				continue
			var label := original.resource_name.to_lower()
			if "bark" in label:
				part.set_surface_override_material(surface, preload("res://presentation/materials/taiga_fir_bark.tres") if "fir" in part.name.to_lower() else bark)
			elif "granite" in label:
				part.set_surface_override_material(surface, granite)
			elif "humus" in label or "clay" in label:
				part.set_surface_override_material(surface, soil)
			elif "needles" in label or "fern" in label:
				part.set_surface_override_material(surface, AuthoredNatureAssetLibrary._natural_material(original, ""))


func refresh_from_save() -> void:
	var data := SaveService.load_slot(0)
	var loop_data := data.get("game_loop", {}) as Dictionary
	var progression_data := data.get("world_progression", {}) as Dictionary
	loop_data = loop_data.duplicate()
	loop_data["story_phase_id"] = progression_data.get("story_phase_id", "phase.ordinary")
	apply_progress_data(loop_data)


func apply_progress_data(loop_data: Dictionary) -> void:
	_laboratory_level = clampi(int(loop_data.get("completed_cycles", 0)), 0, 6)
	if bool(loop_data.get("second_expedition_complete", false)):
		_laboratory_level = maxi(_laboratory_level, 2)
	if bool(loop_data.get("counteragent_brewed", false)):
		_laboratory_level = maxi(_laboratory_level, 3)
	if String(loop_data.get("root_well_plan", "")) != "":
		_laboratory_level = maxi(_laboratory_level, 4)
	var story_levels := {
		"phase.mycelial_choir": 1, "phase.crimson_hunt": 2, "phase.glass_frost": 3,
		"phase.ashen_silence": 4, "phase.mirror_flood": 5, "phase.root_dream": 6,
		"phase.distant_heart": 6,
	}
	_laboratory_level = maxi(_laboratory_level, int(story_levels.get(String(loop_data.get("story_phase_id", "phase.ordinary")), 0)))
	_rebuild_upgrades(loop_data)


func get_laboratory_level() -> int:
	return _laboratory_level


func get_visible_upgrade_names() -> PackedStringArray:
	var names := PackedStringArray()
	if _upgrade_root == null:
		return names
	for child: Node in _upgrade_root.get_children():
		if child is Node3D and child.visible:
			names.append(child.name)
	return names


func _process(delta: float) -> void:
	_time += delta
	if _fire_light != null:
		_fire_light.light_energy = _fire_energy * (1.0 + flicker_amount * (sin(_time * 8.7) + sin(_time * 13.1) * 0.5))
	for index in _flames.size():
		var flame := _flames[index]
		var pulse := 1.0 + sin(_time * (5.5 + index) + float(index) * 1.7) * 0.18
		flame.transform = _flame_rest[index]
		flame.scale *= Vector3(1.0, pulse, 1.0)
		flame.position.y += sin(_time * 4.0 + index) * 0.035
	if _camera != null:
		var mouse := get_viewport().get_mouse_position()
		var viewport_size := get_viewport().get_visible_rect().size
		var parallax := Vector2.ZERO
		if viewport_size.x > 1.0 and viewport_size.y > 1.0:
			parallax = (mouse / viewport_size - Vector2(0.5, 0.5)) * parallax_amount
		_camera.position = _camera_rest + Vector3(parallax.x, -parallax.y, 0.0)


func _rebuild_upgrades(_loop_data: Dictionary) -> void:
	if _upgrade_root == null:
		return
	var names := ["DryingRack", "SporeFilter", "DistillerCoil", "RootResonator", "MirrorSeparator", "ConcordanceCoil"]
	for index: int in names.size():
		var node := _upgrade_root.get_node_or_null(NodePath(names[index])) as Node3D
		if node != null:
			node.visible = _laboratory_level >= index + 1
