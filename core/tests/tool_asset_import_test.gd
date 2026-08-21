extends Node

const ASSETS := {
	"knife": "res://assets/third_party/oga_low_poly_knife/knife.fbx",
	"bottle": "res://assets/third_party/kenney_survival_kit/bottle.glb",
	"campfire_pit": "res://assets/third_party/kenney_survival_kit/campfire-pit.glb",
	"campfire_stand": "res://assets/third_party/kenney_survival_kit/campfire-stand.glb",
	"workbench": "res://assets/third_party/kenney_survival_kit/workbench-grind.glb",
}


func _ready() -> void:
	for asset_name: String in ASSETS:
		var scene := load(ASSETS[asset_name]) as PackedScene
		assert(scene != null, "%s failed to import" % asset_name)
		var instance := scene.instantiate()
		add_child(instance)
		var meshes := instance.find_children("*", "MeshInstance3D", true, false)
		assert(not meshes.is_empty(), "%s has no mesh" % asset_name)
		var combined := AABB()
		var has_bounds := false
		for node: Node in meshes:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			var local_bounds := mesh_instance.transform * mesh_instance.mesh.get_aabb()
			combined = local_bounds if not has_bounds else combined.merge(local_bounds)
			has_bounds = true
		assert(has_bounds, "%s has no renderable bounds" % asset_name)
		print("TOOL_ASSET %s bounds=%s" % [asset_name, combined])
		instance.queue_free()
	print("TOOL ASSET IMPORT TEST PASSED")
	get_tree().quit()
