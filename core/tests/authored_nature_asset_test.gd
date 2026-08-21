extends Node

const ASSET_ROOT := "res://assets/third_party/kenney_nature_kit/models/"
const REPRESENTATIVE_ASSETS := [
	"tree_pineDefaultA.fbx",
	"tree_pineRoundC.fbx",
	"tree_pineTallD.fbx",
	"rock_largeA.fbx",
	"rock_smallF.fbx",
	"log_large.fbx",
	"stump_oldTall.fbx",
	"plant_bushDetailed.fbx",
	"grass_leafs.fbx",
	"mushroom_tanGroup.fbx",
]

var _failures := PackedStringArray()


func _ready() -> void:
	for file_name: String in REPRESENTATIVE_ASSETS:
		var resource := load(ASSET_ROOT + file_name) as PackedScene
		_expect(resource != null, "Nature asset failed to import: %s" % file_name)
		if resource == null:
			continue
		var instance := resource.instantiate()
		add_child(instance)
		var meshes := instance.find_children("*", "MeshInstance3D", true, false)
		_expect(not meshes.is_empty(), "Nature asset has no mesh: %s" % file_name)
		for node: Node in meshes:
			var mesh_instance := node as MeshInstance3D
			_expect(mesh_instance.mesh != null, "Nature asset contains an empty mesh: %s" % file_name)
		instance.free()
	_validate_normalized_scale()
	_finish()


func _validate_normalized_scale() -> void:
	var library := AuthoredNatureAssetLibrary.new()
	for family: StringName in [&"tall_pine", &"round_pine", &"rock", &"forest_floor", &"fungi"]:
		var instance := library.instantiate_variant(family, 0)
		_expect(instance != null, "Authored nature family failed to instantiate: %s" % family)
		if instance == null:
			continue
		add_child(instance)
		_expect(instance.find_children("*", "Camera3D", true, false).is_empty(), "Sanitized %s asset still contains a camera." % family)
		_expect(instance.find_children("*", "Light3D", true, false).is_empty(), "Sanitized %s asset still contains a light." % family)
		var combined := AABB()
		var has_bounds := false
		for node: Node in instance.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			var bounds: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
			combined = bounds if not has_bounds else combined.merge(bounds)
			has_bounds = true
		var longest_side := maxf(combined.size.x, maxf(combined.size.y, combined.size.z))
		_expect(longest_side >= 0.08 and longest_side <= 18.0, "Normalized %s asset has unsafe size %.2fm." % [family, longest_side])
		print("TRip nature bounds %s: %s" % [family, combined.size])
		instance.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TRip authored nature asset test: PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TRip authored nature asset test: FAIL (%d)" % _failures.size())
	get_tree().quit(1)
