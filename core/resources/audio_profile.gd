class_name AudioProfile
extends ContentDefinition

@export var ambience_layers: Array[AudioStream] = []
@export var reverb_bus: StringName = &"World"
@export_range(-60.0, 6.0, 0.1, "suffix:dB") var ambience_db: float = 0.0
@export_range(0.0, 1.0, 0.01) var perception_mix: float = 0.0
@export_range(0.0, 4.0, 0.01) var transition_seconds: float = 0.75

