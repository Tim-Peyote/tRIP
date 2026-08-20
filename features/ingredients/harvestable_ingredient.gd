class_name HarvestableIngredient
extends StaticBody3D

signal harvested(item: ItemInstance)
signal observed(definition_id: StringName)

@export var definition_id: StringName
@export var spawn_id: StringName
@export var available_parts: Array[StringName] = [&"cap", &"stem", &"whole", &"spores"]
@onready var interactable: InteractableComponent = %InteractableComponent

var _selected_index: int = 0

const PART_LABELS: Dictionary = {
	&"cap": "шляпка",
	&"stem": "ножка",
	&"whole": "целиком",
	&"spores": "споры",
	&"berry": "ягоды",
	&"leaf": "листья",
	&"root": "корень",
}

const PART_CAPABILITIES: Dictionary = {
	&"cap": &"separate_cap",
	&"stem": &"separate_stem",
	&"whole": &"",
	&"spores": &"collect_spores",
	&"berry": &"",
	&"leaf": &"cut",
	&"root": &"cut",
}


func _ready() -> void:
	var definition := ContentDB.get_definition(definition_id)
	if definition != null:
		interactable.object_name = definition.display_name
		interactable.inspection_description = definition.description
	interactable.alternative_requested.connect(_on_alternative_requested)
	interactable.inspection_requested.connect(_on_inspection_requested)
	interactable.interaction_completed.connect(_on_interaction_completed)


func get_selected_part() -> StringName:
	return available_parts[_selected_index]


func get_spawn_id() -> StringName:
	return spawn_id if spawn_id != &"" else StringName(get_path())


func get_interaction_prompt(actor: Node) -> String:
	var part := get_selected_part()
	var capability: StringName = PART_CAPABILITIES.get(part, &"")
	var toolbelt := _get_toolbelt(actor)
	var available := capability == &"" or (toolbelt != null and toolbelt.has_capability(capability))
	var verb := "взять целиком" if part == &"whole" else "собрать %s" % PART_LABELS.get(part, part)
	if not available:
		verb = "нет инструмента для: %s" % PART_LABELS.get(part, part)
	return "%s — удерживать: %s  ·  ПКМ выбрать часть" % [interactable.object_name, verb]


func can_receive_interaction(actor: Node) -> bool:
	var capability: StringName = PART_CAPABILITIES.get(get_selected_part(), &"")
	if capability == &"":
		return true
	var toolbelt := _get_toolbelt(actor)
	return toolbelt != null and toolbelt.has_capability(capability)


func get_inspection_data() -> Dictionary:
	return {
		"definition_id": definition_id,
		"title": interactable.object_name,
		"description": interactable.inspection_description,
	}


func _on_alternative_requested(_actor: Node) -> void:
	_selected_index = wrapi(_selected_index + 1, 0, available_parts.size())


func _on_inspection_requested(_actor: Node) -> void:
	observed.emit(definition_id)


func _on_interaction_completed(actor: Node, _action: StringName) -> void:
	if not can_receive_interaction(actor):
		return
	var inventory := actor.find_child("InventoryComponent", true, false) as InventoryComponent
	if inventory == null:
		return
	var part := get_selected_part()
	var toolbelt := _get_toolbelt(actor)
	var capability: StringName = PART_CAPABILITIES.get(part, &"")
	var quality := 0.55 if part == &"whole" else (0.92 if capability == &"" else toolbelt.precision_for(capability))
	if part == &"stem":
		quality *= 0.88
	var item := ItemInstance.new(definition_id, 1.0)
	item.quality = quality
	item.processing_state[&"part"] = part
	item.processing_state[&"harvest_damage"] = 1.0 - quality
	item.processing_state[&"tool_id"] = toolbelt.active_tool_id if toolbelt != null and toolbelt.is_equipped else &""
	if inventory.add_item(item):
		harvested.emit(item)
		queue_free()


func _get_toolbelt(actor: Node) -> ToolbeltComponent:
	if actor == null:
		return null
	return actor.find_child("ToolbeltComponent", true, false) as ToolbeltComponent
