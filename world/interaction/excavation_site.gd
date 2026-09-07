class_name ExcavationSite
extends StaticBody3D

signal state_changed(site_id: StringName, state: Dictionary)
signal excavated(site_id: StringName)

@export var site_id: StringName
@export var loot_table: LootTableDefinition
@export var loot_seed: int = 1
@export_range(1, 5, 1) var required_stages: int = 3
@export var required_capability: StringName = &"dig"

var _stage: int = 0
var _contents: Array[ItemInstance] = []
var _generated: bool = false
var _interactable: InteractableComponent
var _soil: Node3D


func configure(id_value: StringName, table: LootTableDefinition, seed_value: int) -> void:
	site_id = id_value
	loot_table = table
	loot_seed = seed_value


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	_build_presentation()
	_interactable = $InteractableComponent
	_interactable.object_name = "Нарушенный грунт"
	_interactable.primary_verb = "Копать"
	_interactable.hold_duration = 0.9
	_interactable.affordance = "operate"
	_interactable.interaction_completed.connect(_on_interaction_completed)


func can_receive_interaction(actor: Node) -> bool:
	if _stage >= required_stages:
		return true
	var toolbelt := actor.find_child("ToolbeltComponent", true, false) as ToolbeltComponent if actor != null else null
	return required_capability == &"" or (toolbelt != null and toolbelt.has_capability(required_capability))


func get_interaction_prompt(actor: Node) -> String:
	if _stage >= required_stages:
		return "Забрать находку (%d)" % _contents.size() if not _contents.is_empty() else "Осмотреть раскоп"
	if not can_receive_interaction(actor):
		return "Нужна малая лопата — экипировать [Q]"
	return "Раскопать грунт · слой %d/%d" % [_stage + 1, required_stages]


func get_inspection_data() -> Dictionary:
	return {
		"title": "Нарушенный грунт",
		"description": "Земля осела не сама. Под дерном есть каменная выкладка." if _stage == 0 else "Открыто слоев: %d из %d." % [_stage, required_stages],
	}


func to_save_data() -> Dictionary:
	var saved_contents: Array[Dictionary] = []
	for item: ItemInstance in _contents:
		saved_contents.append(item.to_save_data())
	return {"stage": _stage, "generated": _generated, "contents": saved_contents}


func apply_save_data(data: Dictionary) -> void:
	_stage = clampi(int(data.get("stage", 0)), 0, required_stages)
	_generated = bool(data.get("generated", false))
	_contents.clear()
	for raw_item: Variant in data.get("contents", []):
		if raw_item is Dictionary:
			_contents.append(ItemInstance.from_save_data(raw_item))
	_sync_visual(false)


func debug_advance(actor: Node) -> void:
	_on_interaction_completed(actor, &"interact")


func _on_interaction_completed(actor: Node, _action: StringName) -> void:
	if _stage < required_stages:
		if not can_receive_interaction(actor):
			return
		_stage += 1
		_sync_visual(true)
		if _stage == required_stages:
			_generate_contents()
			excavated.emit(site_id)
		_emit_state()
		return
	_transfer_to_actor(actor)


func _generate_contents() -> void:
	if _generated:
		return
	_generated = true
	_contents = loot_table.generate(loot_seed) if loot_table != null else []


func _transfer_to_actor(actor: Node) -> void:
	var inventory := actor.find_child("InventoryComponent", true, false) as InventoryComponent if actor != null else null
	if inventory == null:
		return
	var remaining: Array[ItemInstance] = []
	for item: ItemInstance in _contents:
		if not inventory.add_item(item):
			remaining.append(item)
	_contents = remaining
	_emit_state()


func _emit_state() -> void:
	state_changed.emit(site_id, to_save_data())


func _sync_visual(animated: bool) -> void:
	if _soil == null:
		return
	var target_y := -0.1 - float(_stage) * 0.13
	var target_scale := Vector3(1.0 + float(_stage) * 0.12, maxf(0.15, 1.0 - float(_stage) * 0.24), 1.0 + float(_stage) * 0.1)
	if animated and is_inside_tree():
		var tween := create_tween().set_parallel(true)
		tween.tween_property(_soil, "position:y", target_y, 0.26)
		tween.tween_property(_soil, "scale", target_scale, 0.26)
	else:
		_soil.position.y = target_y
		_soil.scale = target_scale


func _build_presentation() -> void:
	if not has_node("Soil"):
		var template := load("res://world/interaction/excavation_site.tscn") as PackedScene
		var visual := template.instantiate()
		for child: Node in visual.get_children():
			child.owner = null
			visual.remove_child(child)
			add_child(child)
		visual.free()
	_soil = $Soil
