class_name ToolbeltComponent
extends Node

signal tool_changed(tool_id: StringName, is_equipped: bool)

@export var starter_tool_ids: Array[StringName] = [&"tool.field_knife", &"tool.spore_vial", &"tool.field_shovel"]

var active_tool_id: StringName
var is_equipped: bool = false
var _inventory: InventoryComponent
var _active_index: int = 0
var _viewmodels: Dictionary[StringName, Node3D] = {}
var _hand_skeleton: Skeleton3D


func _ready() -> void:
	active_tool_id = starter_tool_ids[0] if not starter_tool_ids.is_empty() else &""
	_inventory = get_parent().find_child("InventoryComponent", true, false) as InventoryComponent
	if _inventory != null:
		for tool_id: StringName in starter_tool_ids:
			if _inventory.count(tool_id) <= 0.0:
				_inventory.add_item(ItemInstance.new(tool_id))
		_inventory.changed.connect(_on_inventory_changed)


func equip(tool_id: StringName) -> bool:
	if not ContentDB.get_definition(tool_id) is ToolDefinition:
		return false
	if _inventory == null or _inventory.count(tool_id) <= 0.0:
		return false
	active_tool_id = tool_id
	is_equipped = true
	_sync_visual()
	tool_changed.emit(active_tool_id, true)
	return true


func unequip() -> void:
	is_equipped = false
	_sync_visual()
	tool_changed.emit(active_tool_id, false)


func _on_inventory_changed() -> void:
	if is_equipped and _inventory.count(active_tool_id) <= 0.0:
		unequip()


func setup_viewmodel(viewmodel: Node3D) -> void:
	setup_viewmodels({&"tool.field_knife": viewmodel})


func setup_viewmodels(viewmodels: Dictionary[StringName, Node3D]) -> void:
	_viewmodels = viewmodels
	if not viewmodels.is_empty():
		_hand_skeleton = (viewmodels.values()[0] as Node3D).get_parent() as Skeleton3D
	_sync_visual()


func has_hand_visual() -> bool:
	return is_equipped and _viewmodels.has(active_tool_id)


func refresh_viewmodels() -> void:
	_sync_visual()


func toggle_active_tool() -> void:
	if is_equipped:
		unequip()
	else:
		equip(active_tool_id)


func cycle_active_tool() -> void:
	if _inventory == null:
		return
	var owned: Array[StringName] = []
	for item: ItemInstance in _inventory.items:
		if ContentDB.get_definition(item.definition_id) is ToolDefinition and item.definition_id not in owned:
			owned.append(item.definition_id)
	if not owned.is_empty():
		equip(owned[wrapi(owned.find(active_tool_id) + 1, 0, owned.size())])


func has_capability(capability: StringName) -> bool:
	if not is_equipped or active_tool_id == &"":
		return false
	var definition := ContentDB.get_definition(active_tool_id) as ToolDefinition
	return definition != null and capability in definition.capabilities


func precision_for(capability: StringName) -> float:
	if not has_capability(capability):
		return 0.0
	var definition := ContentDB.get_definition(active_tool_id) as ToolDefinition
	return definition.base_precision


func get_display_name() -> String:
	if not is_equipped:
		return "Руки свободны"
	var definition := ContentDB.get_definition(active_tool_id)
	return definition.display_name if definition != null else String(active_tool_id)


func to_save_data() -> Dictionary:
	return {"equipment_version": 1, "active_tool_id": String(active_tool_id), "is_equipped": is_equipped}


func apply_save_data(data: Dictionary) -> void:
	# Old saves stored tools only in the belt, not as owned inventory items.
	if not data.has("equipment_version") and _inventory != null:
		for tool_id: StringName in starter_tool_ids:
			if _inventory.count(tool_id) <= 0.0:
				_inventory.add_item(ItemInstance.new(tool_id))
	var saved_id := StringName(data.get("active_tool_id", String(active_tool_id)))
	if ContentDB.get_definition(saved_id) is ToolDefinition:
		active_tool_id = saved_id
		_active_index = starter_tool_ids.find(saved_id)
	is_equipped = bool(data.get("is_equipped", false)) and _inventory != null and _inventory.count(active_tool_id) > 0.0
	_sync_visual()
	tool_changed.emit(active_tool_id, is_equipped)


func _sync_visual() -> void:
	if is_equipped and not _viewmodels.has(active_tool_id) and _hand_skeleton != null:
		var definition := ContentDB.get_definition(active_tool_id) as ToolDefinition
		if definition != null and definition.hand_scene != null:
			var socket := BoneAttachment3D.new()
			socket.bone_name = "mixamorig_RightHand"
			_hand_skeleton.add_child(socket)
			socket.add_child(definition.hand_scene.instantiate())
			_viewmodels[active_tool_id] = socket
	for tool_id: StringName in _viewmodels:
		var viewmodel: Node3D = _viewmodels[tool_id]
		if viewmodel != null:
			viewmodel.visible = is_equipped and tool_id == active_tool_id
