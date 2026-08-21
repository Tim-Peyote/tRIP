class_name RitualCairn
extends StaticBody3D

signal ritual_completed(actor: Node)

var _interactable: InteractableComponent


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	_build_visuals()
	_interactable = InteractableComponent.new()
	_interactable.object_name = "Камни первого обряда"
	_interactable.primary_verb = "Удерживать — разжечь память места"
	_interactable.hold_duration = 1.6
	_interactable.inspection_description = "Камни сложены не для костра. На внутренней стороне — знак из полевого дневника миколога."
	_interactable.interaction_completed.connect(_on_interaction_completed)
	add_child(_interactable)


func set_available(value: bool) -> void:
	visible = value
	if _interactable != null:
		_interactable.enabled = value
	for child: Node in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = not value


func get_interaction_prompt(_actor: Node) -> String:
	return "Провести обряд: вспомнить схему дорожной лаборатории"


func _on_interaction_completed(actor: Node, _action: StringName) -> void:
	set_available(false)
	ritual_completed.emit(actor)


func _build_visuals() -> void:
	var stone_material := StandardMaterial3D.new()
	stone_material.albedo_color = Color("39413b")
	stone_material.roughness = 0.92
	var rune_material := StandardMaterial3D.new()
	rune_material.albedo_color = Color("6fc77e")
	rune_material.emission_enabled = true
	rune_material.emission = Color("3b9b69")
	rune_material.emission_energy_multiplier = 2.1
	for index: int in 7:
		var angle := TAU * float(index) / 7.0
		var stone := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.52, 0.32 + 0.08 * float(index % 3), 0.4)
		stone.mesh = mesh
		stone.material_override = stone_material
		stone.position = Vector3(cos(angle) * 1.05, mesh.size.y * 0.5, sin(angle) * 1.05)
		stone.rotation = Vector3(0.08 * float(index % 2), -angle, 0.05 * float((index + 1) % 3))
		add_child(stone)
	var rune := MeshInstance3D.new()
	var rune_mesh := TorusMesh.new()
	rune_mesh.inner_radius = 0.52
	rune_mesh.outer_radius = 0.61
	rune_mesh.rings = 12
	rune_mesh.ring_segments = 5
	rune.mesh = rune_mesh
	rune.material_override = rune_material
	rune.position.y = 0.08
	add_child(rune)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 1.3
	cylinder.height = 0.7
	shape.shape = cylinder
	shape.position.y = 0.35
	add_child(shape)

