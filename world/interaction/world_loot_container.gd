class_name WorldLootContainer
extends StaticBody3D

signal state_changed(container_id: StringName, state: Dictionary)
signal depleted(container_id: StringName)

@export var container_id: StringName
@export var loot_table: LootTableDefinition
@export var loot_seed: int = 1
@export var title: String = "Полевой тайник"
@export_multiline var closed_description: String = "Следы на крышке подскажут, трогали ли тайник до тебя."

var _interactable: InteractableComponent
var _lid: Node3D
var _contents: Array[ItemInstance] = []
var _generated: bool = false
var _opened: bool = false
var _revealed: bool = true


func configure(id_value: StringName, table: LootTableDefinition, seed_value: int, display_title: String = "Полевой тайник") -> void:
	container_id = id_value
	loot_table = table
	loot_seed = seed_value
	title = display_title
	if is_inside_tree():
		_sync_interactable()


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	_build_presentation()
	_interactable = $InteractableComponent
	_interactable.hold_duration = 0.45
	_interactable.affordance = "operate"
	_interactable.interaction_completed.connect(_on_interaction_completed)
	_interactable.alternative_requested.connect(_on_alternative_requested)
	_sync_interactable()
	_apply_reveal_state()


func set_revealed(value: bool) -> void:
	_revealed = value
	_apply_reveal_state()


func get_interaction_prompt(_actor: Node) -> String:
	if not _opened:
		return "Открыть: %s" % title
	if _contents.is_empty():
		return "Осмотреть пустой тайник"
	return "Забрать содержимое (%d)" % _contents.size()


func get_inspection_data() -> Dictionary:
	var lines := PackedStringArray()
	if _opened:
		for item: ItemInstance in _contents:
			var definition := ContentDB.get_definition(item.definition_id)
			lines.append("%s ×%.0f" % [definition.display_name if definition != null else String(item.definition_id), item.quantity])
	return {
		"title": title,
		"description": closed_description if not _opened else ("Внутри пусто." if lines.is_empty() else "Внутри:\n%s" % "\n".join(lines)),
	}


func to_save_data() -> Dictionary:
	var saved_contents: Array[Dictionary] = []
	for item: ItemInstance in _contents:
		saved_contents.append(item.to_save_data())
	return {"opened": _opened, "generated": _generated, "contents": saved_contents}


func apply_save_data(data: Dictionary) -> void:
	_opened = bool(data.get("opened", false))
	_generated = bool(data.get("generated", false))
	_contents.clear()
	for raw_item: Variant in data.get("contents", []):
		if raw_item is Dictionary:
			_contents.append(ItemInstance.from_save_data(raw_item))
	_apply_open_visual(false)
	_sync_interactable()


func debug_open_and_transfer(actor: Node) -> void:
	_on_interaction_completed(actor, &"interact")
	if not _contents.is_empty():
		_on_interaction_completed(actor, &"interact")


func _on_interaction_completed(actor: Node, _action: StringName) -> void:
	if not _opened:
		_generate_contents_if_needed()
		_opened = true
		_apply_open_visual(true)
		_emit_state()
		return
	_transfer_to_actor(actor)


func _on_alternative_requested(_actor: Node) -> void:
	if _opened and not _contents.is_empty():
		_opened = false
		_apply_open_visual(true)
		_emit_state()


func _generate_contents_if_needed() -> void:
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
	_sync_interactable()
	_emit_state()
	if _contents.is_empty():
		depleted.emit(container_id)


func _emit_state() -> void:
	state_changed.emit(container_id, to_save_data())


func _sync_interactable() -> void:
	if _interactable == null:
		return
	_interactable.object_name = title
	_interactable.primary_verb = "Открыть" if not _opened else "Забрать"
	_interactable.inspection_description = closed_description


func _apply_reveal_state() -> void:
	visible = _revealed
	collision_layer = 4 if _revealed else 0
	if _interactable != null:
		_interactable.enabled = _revealed


func _apply_open_visual(animated: bool) -> void:
	if _lid == null:
		return
	var target := -1.05 if _opened else 0.0
	if animated and is_inside_tree():
		var tween := create_tween()
		tween.tween_property(_lid, "rotation:x", target, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_lid.rotation.x = target


func _build_presentation() -> void:
	if not has_node("Lid"):
		var template := load("res://world/interaction/world_loot_container.tscn") as PackedScene
		var visual := template.instantiate()
		for child: Node in visual.get_children():
			child.owner = null
			visual.remove_child(child)
			add_child(child)
		visual.free()
	_lid = $Lid
