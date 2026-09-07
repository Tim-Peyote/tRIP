@static_unload
extends RefCounted
## Shared by the menu and the playable station; never touches liquids or VFX.
static var _cache: Dictionary = {}

static func apply_to(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null:
			continue
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface)
			if original == null:
				continue
			var label := original.resource_name.to_lower()
			var kind := ""
			if "heartwood" in label: kind = "wood"
			elif "leather" in label: kind = "leather"
			elif "forged iron" in label: kind = "iron"
			elif "copper" in label: kind = "copper"
			elif "stoneware" in label or "glazed" in label: kind = "ceramic"
			if not kind.is_empty():
				part.set_surface_override_material(surface, material_for(kind))

static func material_for(kind: String) -> Material:
	if _cache.has(kind): return _cache[kind]
	var material := ShaderMaterial.new()
	material.shader = preload("res://presentation/materials/laboratory_surface.gdshader")
	var settings: Array = {
		"wood": [Color("8b7963"), 0.88, 0.0, 0],
		"leather": [Color("493022"), 0.78, 0.0, 1],
		"iron": [Color("444441"), 0.63, 0.85, 2],
		"copper": [Color("79583e"), 0.48, 0.8, 3],
		"ceramic": [Color("818276"), 0.28, 0.0, 4],
	}[kind]
	material.set_shader_parameter("base_color", settings[0])
	material.set_shader_parameter("surface_roughness", settings[1])
	material.set_shader_parameter("surface_metallic", settings[2])
	material.set_shader_parameter("surface_kind", settings[3])
	material.set_shader_parameter("wood_texture", preload("res://assets/textures/taiga_realistic/cedar_wood_albedo.png"))
	_cache[kind] = material
	return material
