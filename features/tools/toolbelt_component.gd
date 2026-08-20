class_name ToolbeltComponent
extends Node

signal tool_changed(tool_id: StringName, is_equipped: bool)

@export var starter_tool_ids: Array[StringName] = [&"tool.field_knife", &"tool.spore_vial"]

var active_tool_id: StringName
var is_equipped: bool = true
var _active_index: int = 0
var _viewmodels: Dictionary[StringName, Node3D] = {}


func _ready() -> void:
	active_tool_id = starter_tool_ids[0] if not starter_tool_ids.is_empty() else &""


func setup_viewmodel(viewmodel: Node3D) -> void:
	setup_viewmodels({&"tool.field_knife": viewmodel})


func setup_viewmodels(viewmodels: Dictionary[StringName, Node3D]) -> void:
	_viewmodels = viewmodels
	_sync_visual()


func toggle_active_tool() -> void:
	is_equipped = not is_equipped
	_sync_visual()
	tool_changed.emit(active_tool_id, is_equipped)


func cycle_active_tool() -> void:
	if starter_tool_ids.is_empty():
		return
	_active_index = wrapi(_active_index + 1, 0, starter_tool_ids.size())
	active_tool_id = starter_tool_ids[_active_index]
	is_equipped = true
	_sync_visual()
	tool_changed.emit(active_tool_id, true)


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
	return {"active_tool_id": String(active_tool_id), "is_equipped": is_equipped}


func apply_save_data(data: Dictionary) -> void:
	var saved_id := StringName(data.get("active_tool_id", String(active_tool_id)))
	if saved_id in starter_tool_ids:
		active_tool_id = saved_id
		_active_index = starter_tool_ids.find(saved_id)
	is_equipped = bool(data.get("is_equipped", true))
	_sync_visual()
	tool_changed.emit(active_tool_id, is_equipped)


func _sync_visual() -> void:
	for tool_id: StringName in _viewmodels:
		var viewmodel: Node3D = _viewmodels[tool_id]
		if viewmodel != null:
			viewmodel.visible = is_equipped and tool_id == active_tool_id
