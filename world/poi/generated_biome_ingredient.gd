class_name GeneratedBiomeIngredient
extends StaticBody3D

signal harvested(item: ItemInstance)
signal observed(definition_id: StringName)

var definition_id: StringName
var spawn_id: StringName
var _interactable: InteractableComponent
var _accent: Color


func configure(id: StringName, unique_spawn_id: StringName, accent: Color, ecology_family: int) -> void:
	definition_id = id
	spawn_id = unique_spawn_id
	_accent = accent
	collision_layer = 4
	collision_mask = 0
	_build_visual(ecology_family)
	_interactable = InteractableComponent.new()
	_interactable.name = "InteractableComponent"
	var content := ContentDB.get_definition(id)
	_interactable.object_name = content.display_name if content != null else String(id)
	_interactable.primary_verb = "Удерживать — взять локальный образец"
	_interactable.hold_duration = 0.7
	_interactable.inspection_description = content.description if content != null else "Образец существует только в этом слое мира."
	_interactable.inspection_requested.connect(func(_actor: Node) -> void: observed.emit(definition_id))
	_interactable.interaction_completed.connect(_on_interaction_completed)
	add_child(_interactable)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.35
	collision.shape = shape
	collision.position.y = 0.68
	add_child(collision)


func get_interaction_prompt(_actor: Node) -> String:
	return "%s · локальный образец этого мира" % _interactable.object_name


func get_inspection_data() -> Dictionary:
	return {"definition_id": definition_id, "title": _interactable.object_name, "description": _interactable.inspection_description}


func set_revealed(value: bool) -> void:
	visible = value
	process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	if _interactable != null:
		_interactable.enabled = value
	for node: Node in find_children("*", "CollisionShape3D", true, false):
		(node as CollisionShape3D).disabled = not value


func _on_interaction_completed(actor: Node, _action: StringName) -> void:
	var inventory := actor.find_child("InventoryComponent", true, false) as InventoryComponent
	if inventory == null:
		return
	var item := ItemInstance.new(definition_id, 1.0)
	item.quality = 0.94
	item.processing_state[&"part"] = &"whole"
	item.processing_state[&"source_world"] = get_meta(&"phase_id", &"")
	if inventory.add_item(item):
		harvested.emit(item)
		queue_free()


func _build_visual(ecology_family: int) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = _accent.darkened(0.18)
	material.roughness = 0.54
	material.emission_enabled = true
	material.emission = _accent
	material.emission_energy_multiplier = 1.8
	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.055 + float(ecology_family % 3) * 0.025
	stem_mesh.bottom_radius = 0.16
	stem_mesh.height = 0.82 + float(ecology_family % 4) * 0.13
	stem_mesh.radial_segments = 6
	stem.mesh = stem_mesh
	stem.material_override = material
	stem.position.y = stem_mesh.height * 0.5
	add_child(stem)
	var crown := MeshInstance3D.new()
	var crown_mesh: PrimitiveMesh
	if ecology_family in [3, 4]:
		var prism := PrismMesh.new()
		prism.size = Vector3(0.55, 0.9, 0.32)
		crown_mesh = prism
	elif ecology_family in [5, 6]:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.24
		torus.outer_radius = 0.38
		torus.rings = 10
		torus.ring_segments = 6
		crown_mesh = torus
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.34
		sphere.height = 0.48
		sphere.radial_segments = 7
		sphere.rings = 4
		crown_mesh = sphere
	crown.mesh = crown_mesh
	crown.material_override = material
	crown.position.y = stem_mesh.height + 0.15
	crown.rotation = Vector3(0.18, 0.4 * float(ecology_family), 0.12)
	add_child(crown)
	var glow := OmniLight3D.new()
	glow.light_color = _accent
	glow.light_energy = 0.72
	glow.omni_range = 2.4
	glow.position.y = 0.9
	add_child(glow)
