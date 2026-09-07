extends Node

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 5:
		get_tree().quit(2)
		return
	var phase := load(args[0]) as WorldPhaseDefinition
	if phase == null:
		get_tree().quit(3)
		return
	var terrain := ExpeditionTerrain.new()
	terrain.set("_run_seed", int(args[1]))
	terrain.set("_phase_definition", phase)
	terrain.call("_configure_noise")
	terrain.set("_terrain_material", terrain.call("_build_terrain_material"))
	var center := Vector2i(int(args[2]), int(args[3]))
	var radius := clampi(int(args[4]), 0, 2)
	for z: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			terrain.call("_build_chunk", center + Vector2i(x, z), 1)
	var preview := Node3D.new()
	preview.name = "GeneratedPreview"
	for child: Node in terrain.get_children():
		terrain.remove_child(child)
		preview.add_child(child)
		_strip_and_own(child, preview)
	var packed := PackedScene.new()
	var result := packed.pack(preview)
	if result == OK:
		result = ResourceSaver.save(packed, "user://biome_editor_preview.tscn")
	preview.free()
	terrain.free()
	get_tree().quit(0 if result == OK else 4)

func _strip_and_own(node: Node, scene_root: Node) -> void:
	node.set_script(null)
	node.unique_name_in_owner = false
	node.owner = scene_root
	for child: Node in node.get_children():
		_strip_and_own(child, scene_root)
