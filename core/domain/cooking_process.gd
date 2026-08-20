class_name CookingProcess
extends RefCounted

signal event_appended(event: CookingProcessEvent)

var events: Array[CookingProcessEvent] = []


func append_event(event: CookingProcessEvent) -> void:
	assert(event != null, "CookingProcess cannot append a null event.")
	events.append(event)
	event_appended.emit(event)


func clear() -> void:
	events.clear()

