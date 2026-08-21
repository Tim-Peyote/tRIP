class_name PhysicalInteractionShowcase
extends Node3D

var _terrain: ExpeditionTerrain


func setup(terrain: ExpeditionTerrain) -> void:
	_terrain = terrain
	_build_prop("Полевой ящик", &"wood", Vector3(-2.0, 0, 13.0), Vector3(0.72, 0.48, 0.54), 4.2, Color("5a3620"), true)
	_build_prop("Берестяной короб", &"organic", Vector3(-1.0, 0, 13.5), Vector3(0.42, 0.36, 0.42), 1.1, Color("a56a37"), true)
	_build_prop("Камень обряда", &"stone", Vector3(1.05, 0, 13.4), Vector3(0.46, 0.34, 0.52), 7.5, Color("3c4742"), false)
	_build_prop("Медный котелок", &"metal", Vector3(2.0, 0, 13.0), Vector3(0.46, 0.3, 0.46), 2.6, Color("8b5130"), false)


func _build_prop(
	display_name: String,
	material_kind: StringName,
	position_2d: Vector3,
	size: Vector3,
	mass: float,
	color: Color,
	flammable: bool
) -> void:
	var body := RigidBody3D.new()
	body.name = display_name.replace(" ", "_")
	body.mass = mass
	body.collision_layer = 1
	body.collision_mask = 1 | 2
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 6
	var world_position := position_2d
	world_position.y = _terrain.get_height_at_global(world_position) + size.y * 0.6 + 0.15
	body.position = world_position
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9 if material_kind != &"metal" else 0.42
	material.metallic = 0.72 if material_kind == &"metal" else 0.0
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var properties := PhysicalPropertyComponent.new()
	properties.display_name = display_name
	properties.material_kind = String(material_kind)
	properties.flammable = flammable
	properties.conductive = material_kind == &"metal"
	properties.buoyant = material_kind in [&"wood", &"organic"]
	body.add_child(properties)
	_add_detail(body, size, material_kind)


func _add_detail(body: RigidBody3D, size: Vector3, material_kind: StringName) -> void:
	if material_kind == &"wood":
		for direction: float in [-1.0, 1.0]:
			var band := MeshInstance3D.new()
			var band_mesh := BoxMesh.new()
			band_mesh.size = Vector3(0.055, size.y + 0.025, size.z + 0.025)
			band.mesh = band_mesh
			band.position.x = direction * size.x * 0.28
			var band_material := StandardMaterial3D.new()
			band_material.albedo_color = Color("242b27")
			band_material.metallic = 0.5
			band.material_override = band_material
			body.add_child(band)
	elif material_kind == &"metal":
		var rim := MeshInstance3D.new()
		var rim_mesh := TorusMesh.new()
		rim_mesh.inner_radius = size.x * 0.36
		rim_mesh.outer_radius = size.x * 0.5
		rim.mesh = rim_mesh
		rim.position.y = size.y * 0.52
		body.add_child(rim)
