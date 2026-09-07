extends Node

const SAMPLE_FRAMES := 120


func _ready() -> void:
	var main := (load("res://app/main/main.tscn") as PackedScene).instantiate() as TripMain
	add_child(main)
	await get_tree().process_frame
	main.call("_on_game_requested", 117, true)
	await get_tree().process_frame
	var level := main.find_child("ExpeditionSession", true, false) as SessionController
	var terrain := level.get_node("ExpeditionTerrain") as ExpeditionTerrain
	var route_z := 132.0
	var viewpoint := Vector3(float(terrain.call("_route_center_x", route_z)), 0.0, route_z)
	viewpoint.y = terrain.get_height_at_global(viewpoint) + 0.12
	terrain.ensure_area_at(viewpoint)
	level.player.global_position = viewpoint
	level.player.rotation.y = PI
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	level.get_biome_hazard().set_process(false)
	var stream_guard := 0
	while terrain.get_pending_chunk_count() > 0 and stream_guard < 120:
		stream_guard += 1
		await get_tree().process_frame
	for _warmup: int in 30:
		await get_tree().process_frame
	var fps_sum := 0.0
	var min_fps := INF
	var min_fps_sample := -1
	var min_fps_pending_chunks := 0
	var min_fps_nodes := 0
	var max_draw_calls := 0.0
	var max_primitives := 0.0
	for _sample: int in SAMPLE_FRAMES:
		await get_tree().process_frame
		var fps := Performance.get_monitor(Performance.TIME_FPS)
		fps_sum += fps
		if fps < min_fps:
			min_fps = fps
			min_fps_sample = _sample
			min_fps_pending_chunks = terrain.get_pending_chunk_count()
			min_fps_nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		max_draw_calls = maxf(max_draw_calls, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		max_primitives = maxf(max_primitives, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("TRip render probe: avg_fps=%.1f min_fps=%.1f max_draw_calls=%d max_primitives=%d nodes=%d" % [
		fps_sum / SAMPLE_FRAMES,
		min_fps,
		int(max_draw_calls),
		int(max_primitives),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	])
	print("TRip scene load: geometry=%d multimeshes=%d collisions=%d terrain_chunks=%d" % [
		level.find_children("*", "GeometryInstance3D", true, false).size(),
		level.find_children("*", "MultiMeshInstance3D", true, false).size(),
		level.find_children("*", "CollisionShape3D", true, false).size(),
		terrain.get_loaded_chunk_count(),
	])
	print("TRip worst frame: sample=%d pending_chunks=%d nodes=%d" % [min_fps_sample, min_fps_pending_chunks, min_fps_nodes])
	get_tree().quit(0)
