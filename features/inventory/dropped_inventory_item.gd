class_name DroppedInventoryItem
extends RigidBody3D

signal collected(item: ItemInstance)

var item: ItemInstance
var _interactable: InteractableComponent


func configure(value: ItemInstance) -> void:
	item = ItemInstance.from_save_data(value.to_save_data())
	name = "Dropped_%s" % String(item.definition_id).get_file()
	collision_layer = 4
	collision_mask = 1
	mass = 0.35
	linear_damp = 0.35
	angular_damp = 0.8
	set_meta(&"interaction_name", _display_name())
	_build_visual()
	_build_interaction()


func get_interaction_prompt(_actor: Node) -> String:
	return "E · в сумку   |   ПКМ · взять рукой   ·   %s" % _display_name()


func get_inspection_data() -> Dictionary:
	var definition := ContentDB.get_definition(item.definition_id) if item != null else null
	return {
		"definition_id": item.definition_id if item != null else &"",
		"title": _display_name(),
		"description": definition.description if definition != null else "Полевой образец.",
	}


func can_receive_interaction(actor: Node) -> bool:
	return item != null and actor != null and actor.find_child("InventoryComponent", true, false) is InventoryComponent


func collect_into(actor: Node) -> bool:
	if not can_receive_interaction(actor):
		return false
	var inventory := actor.find_child("InventoryComponent", true, false) as InventoryComponent
	var restored := ItemInstance.from_save_data(item.to_save_data())
	if not inventory.add_item(restored):
		return false
	collected.emit(restored)
	queue_free()
	return true


func _on_interaction_completed(actor: Node, _action: StringName) -> void:
	collect_into(actor)


func _display_name() -> String:
	if item == null:
		return "образец"
	var definition := ContentDB.get_definition(item.definition_id)
	return definition.display_name if definition != null else String(item.definition_id)


func _build_interaction() -> void:
	_interactable = InteractableComponent.new()
	_interactable.name = "InteractableComponent"
	_interactable.object_name = _display_name()
	_interactable.primary_verb = "Поднять"
	_interactable.affordance = "collect"
	_interactable.inspection_description = "Выброшенный полевой образец. Его можно поднять обратно или переместить рукой."
	_interactable.interaction_completed.connect(_on_interaction_completed)
	_interactable.alternative_requested.connect(_on_alternative_requested)
	add_child(_interactable)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.18
	collision.shape = shape
	add_child(collision)


func _on_alternative_requested(actor: Node) -> void:
	if actor is FirstPersonController:
		(actor as FirstPersonController).interactor.try_grab_body(self)


func _build_visual() -> void:
	var definition := ContentDB.get_definition(item.definition_id)
	var accent := Color("a7ba77")
	if definition is ConsumableDefinition:
		accent = Color("86c8b5")
	elif definition is ItemDefinition:
		accent = Color("c49b70")
	var material := StandardMaterial3D.new()
	material.albedo_color = accent
	material.roughness = 0.72
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.28
	mesh.radial_segments = 8
	mesh.rings = 4
	visual.mesh = mesh
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(visual)
