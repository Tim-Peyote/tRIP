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


func to_save_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: CookingProcessEvent in events:
		result.append(event.to_save_data())
	return result


func apply_save_data(data: Array) -> void:
	events.clear()
	for raw_event: Variant in data:
		if raw_event is Dictionary:
			events.append(CookingProcessEvent.from_save_data(raw_event as Dictionary))
