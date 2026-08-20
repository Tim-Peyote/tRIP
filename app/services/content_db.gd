extends Node

signal rebuilt(definition_count: int)
signal validation_failed(messages: PackedStringArray)

const CONTENT_ROOT: String = "res://content"

var _definitions: Dictionary[StringName, ContentDefinition] = {}


func rebuild() -> bool:
	_definitions.clear()
	var messages := PackedStringArray()
	_scan_directory(CONTENT_ROOT, messages)
	if not messages.is_empty():
		validation_failed.emit(messages)
		for message: String in messages:
			push_error(message)
		return false
	rebuilt.emit(_definitions.size())
	return true


func get_definition(id: StringName) -> ContentDefinition:
	return _definitions.get(id)


func get_all() -> Array[ContentDefinition]:
	var result: Array[ContentDefinition] = []
	result.assign(_definitions.values())
	return result


func _scan_directory(path: String, messages: PackedStringArray) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = directory.get_next()
			continue
		var entry_path := path.path_join(entry)
		if directory.current_is_dir():
			_scan_directory(entry_path, messages)
		elif entry.get_extension() in ["tres", "res"]:
			_register_resource(entry_path, messages)
		entry = directory.get_next()
	directory.list_dir_end()


func _register_resource(path: String, messages: PackedStringArray) -> void:
	var resource := ResourceLoader.load(path)
	if not resource is ContentDefinition:
		return
	var definition := resource as ContentDefinition
	for message: String in definition.validate():
		messages.append("%s: %s" % [path, message])
	if definition.id == &"":
		return
	if _definitions.has(definition.id):
		messages.append("Duplicate content id '%s' in %s" % [definition.id, path])
		return
	_definitions[definition.id] = definition

