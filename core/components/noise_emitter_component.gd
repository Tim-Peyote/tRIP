class_name NoiseEmitterComponent
extends Node3D

signal gameplay_noise_emitted(event: GameplayNoiseEvent)


func emit_noise(radius: float, tag: StringName, intensity: float = 1.0) -> GameplayNoiseEvent:
	var event := GameplayNoiseEvent.new()
	event.origin = global_position
	event.radius = maxf(0.0, radius)
	event.tag = tag
	event.intensity = clampf(intensity, 0.0, 1.0)
	event.source = get_parent()
	gameplay_noise_emitted.emit(event)
	return event

