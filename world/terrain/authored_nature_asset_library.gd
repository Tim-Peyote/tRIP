class_name AuthoredNatureAssetLibrary
extends RefCounted

const ROOT := "res://assets/third_party/kenney_nature_kit/models/"
const TALL_PINES := [
	"tree_pineTallA.fbx", "tree_pineTallB.fbx", "tree_pineTallC.fbx", "tree_pineTallD.fbx",
	"tree_pineDefaultA.fbx", "tree_pineDefaultB.fbx",
]
const ROUND_PINES := [
	"tree_pineRoundA.fbx", "tree_pineRoundB.fbx", "tree_pineRoundC.fbx",
	"tree_pineRoundD.fbx", "tree_pineRoundE.fbx", "tree_pineRoundF.fbx",
]
const YOUNG_PINES := [
	"tree_pineSmallA.fbx", "tree_pineSmallB.fbx", "tree_pineSmallC.fbx", "tree_pineSmallD.fbx",
]
const ROCKS := [
	"rock_largeA.fbx", "rock_largeB.fbx", "rock_largeC.fbx",
	"rock_largeD.fbx", "rock_largeE.fbx", "rock_largeF.fbx",
	"rock_smallA.fbx", "rock_smallB.fbx", "rock_smallC.fbx", "rock_smallD.fbx", "rock_smallE.fbx",
	"rock_smallF.fbx", "rock_smallG.fbx", "rock_smallH.fbx", "rock_smallI.fbx",
]
const FOREST_FLOOR := [
	"log.fbx", "log_large.fbx", "stump_old.fbx", "stump_oldTall.fbx",
	"stump_round.fbx", "stump_roundDetailed.fbx", "plant_bush.fbx",
	"plant_bushDetailed.fbx", "plant_bushLarge.fbx", "plant_bushSmall.fbx",
]
const FUNGI := [
	"mushroom_red.fbx", "mushroom_redGroup.fbx",
	"mushroom_tan.fbx", "mushroom_tanGroup.fbx",
]
const GRASS_CLUSTERS := ["grass.fbx", "grass_large.fbx", "grass_leafs.fbx"]

var _scene_cache: Dictionary[String, PackedScene] = {}


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
	instance.set_meta(&"asset_source", &"kenney_nature_kit")
	# Imported model scenes are visual ingredients, never self-contained levels.
	# Strip exporter cameras and lights before the instance enters SceneTree so an
	# asset cannot take over the gameplay viewport or alter the authored lighting.
	for node: Node in instance.find_children("*", "Camera3D", true, false):
		node.free()
	for node: Node in instance.find_children("*", "Light3D", true, false):
		node.free()
	for node: Node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var is_major_silhouette := family in [&"tall_pine", &"round_pine", &"young_pine"]
		mesh_instance.visibility_range_end = 82.0 if is_major_silhouette else (60.0 if family == &"rock" else 46.0)
		mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if not is_major_silhouette and family != &"rock":
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _base_scale_for_family(family: StringName) -> float:
	match family:
		&"tall_pine":
			return 4.6
		&"round_pine":
			return 4.0
		&"young_pine":
			return 3.3
		&"rock":
			return 1.45
		&"forest_floor":
			return 2.8
		&"fungi":
			return 2.1
		&"grass_cluster":
			return 2.4
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
