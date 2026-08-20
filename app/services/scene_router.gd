extends Node

signal transition_started(scene_path: String)
signal transition_finished(scene_path: String)
signal transition_failed(scene_path: String, reason: String)

var _busy: bool = false


func change_scene(scene_path: String) -> bool:
	if _busy:
		transition_failed.emit(scene_path, "A scene transition is already running.")
		return false
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		transition_failed.emit(scene_path, "PackedScene does not exist.")
		return false
	_busy = true
	transition_started.emit(scene_path)
	var result: Error = get_tree().change_scene_to_file(scene_path)
	_busy = false
	if result != OK:
		transition_failed.emit(scene_path, error_string(result))
		return false
	transition_finished.emit(scene_path)
	return true

