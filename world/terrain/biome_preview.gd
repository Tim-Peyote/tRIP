@tool
extends Node3D

@export_file("*.tres") var phase_path: String = "res://content/world_phases/ordinary_world.tres"
@export var seed_value: int = 61937
@export var chunk_center: Vector2i = Vector2i(0, 2)
@export_range(0, 2) var radius: int = 1
@export_tool_button("Обновить предпросмотр", "Reload") var rebuild_action: Callable = rebuild_preview


func rebuild_preview() -> void:
	if not Engine.is_editor_hint():
		return
	var output: Array = []
	# Isolated engine process: preview never starts gameplay or reads a save slot.
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "res://world/terrain/preview_worker.tscn", "--", phase_path, str(seed_value), str(chunk_center.x), str(chunk_center.y), str(radius)])
	var result := OS.execute(OS.get_executable_path(), args, output, true)
	if result != 0:
		push_error("Preview generation failed: " + str(output))
		return
	var path := "user://biome_editor_preview.tscn"
	var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		return
	var previous := get_node_or_null("GeneratedPreview")
	if previous != null:
		remove_child(previous)
		previous.queue_free()
	var preview := packed.instantiate()
	preview.name = "GeneratedPreview"
	add_child(preview)
	# Preview is transient; keep manual work under AuthoredLandmarks.
	preview.scene_file_path = ""
