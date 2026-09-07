@static_unload
class_name AuthoredNatureAssetLibrary
extends RefCounted

const ROOT := "res://assets/models/taiga/"
static var _foliage_materials: Dictionary = {}


static func _natural_material(original: Material, file_name: String) -> Material:
	if original != null and "heartwood" in original.resource_name.to_lower():
		return load("res://presentation/materials/tree_cut.tres") as Material
	if file_name.begins_with("granite_"):
		return load("res://presentation/materials/taiga_granite.tres") as Material
	if original != null and "bark" in original.resource_name.to_lower():
		if "fir" in file_name:
			return load("res://presentation/materials/taiga_fir_bark.tres") as Material
		return load("res://presentation/materials/taiga_bark.tres") as Material
	if original is StandardMaterial3D:
		var label := original.resource_name.to_lower()
		if "needles" in label or "fern" in label:
			var key := original.get_instance_id()
			if not _foliage_materials.has(key):
				var foliage := original.duplicate() as StandardMaterial3D
				foliage.backlight_enabled = true
				foliage.backlight = Color(0.12, 0.16, 0.055)
				foliage.roughness = 0.87
				foliage.metallic_specular = 0.2
				_foliage_materials[key] = foliage
			return _foliage_materials[key]
	return original
const TALL_PINES := [
	"fir.glb", "cedar.glb", "wind_cedar.glb",
]
const ROUND_PINES := [
	"cedar.glb", "wind_cedar.glb",
]
const YOUNG_PINES := [
	"young_fir.glb",
]
const ROCKS := [
	"granite_round.glb", "granite_split.glb", "granite_moss.glb",
]
const FOREST_FLOOR := [
	"deadfall.glb", "stump.glb", "berry_shrub.glb",
]
const FUNGI := [
	"fungi.glb",
]
const GRASS_CLUSTERS := ["fern.glb", "sedge.glb"]

var _scene_cache: Dictionary[String, PackedScene] = {}
var _mesh_cache: Dictionary[String, Mesh] = {}


func get_runtime_mesh(file_name: String) -> Mesh:
	if _mesh_cache.has(file_name):
		return _mesh_cache[file_name]
	var packed := load(ROOT + file_name) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate() as Node3D
	var parts := instance.find_children("*", "MeshInstance3D", true, false)
	if parts.size() == 1:
		var part := parts[0] as MeshInstance3D
		var baked_transform := part.transform
		var parent := part.get_parent() as Node3D
		while parent != null:
			baked_transform = parent.transform * baked_transform
			parent = parent.get_parent() as Node3D
		if baked_transform.is_equal_approx(Transform3D.IDENTITY):
			# SurfaceTool reconstruction drops imported LOD index buffers.
			# Keep those buffers for the common single-mesh Blender export.
			var preserved := part.mesh.duplicate() as ArrayMesh
			for surface: int in preserved.get_surface_count():
				preserved.surface_set_material(surface, _natural_material(preserved.surface_get_material(surface), file_name))
			instance.free()
			_mesh_cache[file_name] = preserved
			return preserved
	var combined := ArrayMesh.new()
	for node: Node in instance.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		var transform := part.transform
		var ancestor := part.get_parent() as Node3D
		while ancestor != null:
			transform = ancestor.transform * transform
			ancestor = ancestor.get_parent() as Node3D
		for surface in part.mesh.get_surface_count():
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			builder.append_from(part.mesh, surface, transform)
			builder.set_material(_natural_material(part.mesh.surface_get_material(surface), file_name))
			builder.commit(combined)
	instance.free()
	_mesh_cache[file_name] = combined
	return combined


func instantiate_variant(family: StringName, variant: int) -> Node3D:
	var files := _files_for_family(family)
	if files.is_empty():
		return null
	var file_name: String = files[posmod(variant, files.size())]
	var scene := _scene_cache.get(file_name) as PackedScene
	if scene == null:
		scene = load(ROOT + file_name) as PackedScene
		if scene == null:
			return null
		_scene_cache[file_name] = scene
	var instance := scene.instantiate() as Node3D
	if instance == null:
		return null
	instance.name = "AuthoredNature_%s_%02d" % [family, posmod(variant, files.size())]
	instance.scale = Vector3.ONE * _base_scale_for_family(family)
	instance.set_meta(&"authored_nature", true)
	instance.set_meta(&"asset_source", &"trip_blender_taiga")
	# Imported model scenes are visual ingredients, never self-contained levels.
	# Strip exporter cameras and lights before the instance enters SceneTree so an
	# asset cannot take over the gameplay viewport or alter the authored lighting.
	for node: Node in instance.find_children("*", "Camera3D", true, false):
		node.free()
	for node: Node in instance.find_children("*", "Light3D", true, false):
		node.free()
	for node: Node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface: int in mesh_instance.mesh.get_surface_count():
			mesh_instance.set_surface_override_material(surface, _natural_material(mesh_instance.mesh.surface_get_material(surface), file_name))
		var is_major_silhouette := family in [&"tall_pine", &"round_pine", &"young_pine"]
		mesh_instance.visibility_range_end = 82.0 if is_major_silhouette else (60.0 if family == &"rock" else 46.0)
		mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if not is_major_silhouette and family != &"rock":
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _base_scale_for_family(_family: StringName) -> float:
	# All authored replacements use metres; no kit-specific scale correction.
	return 1.0


func _files_for_family(family: StringName) -> Array:
	match family:
		&"tall_pine":
			return TALL_PINES
		&"round_pine":
			return ROUND_PINES
		&"young_pine":
			return YOUNG_PINES
		&"rock":
			return ROCKS
		&"forest_floor":
			return FOREST_FLOOR
		&"fungi":
			return FUNGI
		&"grass_cluster":
			return GRASS_CLUSTERS
	return []
