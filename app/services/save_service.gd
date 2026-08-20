extends Node

signal save_completed(slot_id: int)
signal save_failed(slot_id: int, reason: String)

const SAVE_SCHEMA_VERSION: int = 2
const SAVE_DIRECTORY: String = "user://saves"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY))


func has_save(slot_id: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot_id))


func save_slot(slot_id: int, payload: Dictionary) -> bool:
	if slot_id < 0:
		save_failed.emit(slot_id, "Slot id must be non-negative.")
		return false
	var envelope: Dictionary = {
		"schema_version": SAVE_SCHEMA_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"payload": payload,
	}
	var final_path := _slot_path(slot_id)
	var temporary_path := final_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		save_failed.emit(slot_id, error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(envelope, "\t"))
	file.close()
	var absolute_final := ProjectSettings.globalize_path(final_path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(final_path):
		DirAccess.remove_absolute(absolute_final)
	var rename_error := DirAccess.rename_absolute(absolute_temporary, absolute_final)
	if rename_error != OK:
		save_failed.emit(slot_id, error_string(rename_error))
		return false
	save_completed.emit(slot_id)
	return true


func load_slot(slot_id: int) -> Dictionary:
	var path := _slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	var envelope: Dictionary = parsed
	if int(envelope.get("schema_version", -1)) > SAVE_SCHEMA_VERSION:
		return {}
	return _migrate(envelope)


func delete_slot(slot_id: int) -> bool:
	var path := _slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


func _migrate(envelope: Dictionary) -> Dictionary:
	var version := int(envelope.get("schema_version", 1))
	var payload := envelope.get("payload", {}) as Dictionary
	if version == 1:
		# Version 1 only contained prototype payloads. Missing session sections use defaults.
		version = 2
	return payload


func _slot_path(slot_id: int) -> String:
	return "%s/slot_%02d.json" % [SAVE_DIRECTORY, slot_id]
