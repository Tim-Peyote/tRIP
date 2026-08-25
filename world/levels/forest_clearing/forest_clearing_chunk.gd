class_name ForestClearingChunk
extends Node3D

@onready var forest_light: DirectionalLight3D = %ForestLight
@onready var spore_glow: OmniLight3D = %SporeGlow
@onready var listener: ListenerCreature = %Listener


func _ready() -> void:
	# The global biome controller owns the sun and its cascaded shadow map. This
	# legacy local directional light produced a second shadow direction and washed
	# out every material in the opening clearing.
	forest_light.visible = false
	forest_light.shadow_enabled = false


func apply_phase(phase: int) -> void:
	match phase:
		ExpeditionClock.Phase.DAY:
			forest_light.light_color = Color(0.27, 0.48, 0.32)
			forest_light.light_energy = 0.85
			spore_glow.light_energy = 1.1
		ExpeditionClock.Phase.DUSK:
			forest_light.light_color = Color(0.31, 0.24, 0.34)
			forest_light.light_energy = 0.48
			spore_glow.light_energy = 1.7
		ExpeditionClock.Phase.NIGHT:
			forest_light.light_color = Color(0.12, 0.18, 0.31)
			forest_light.light_energy = 0.22
			spore_glow.light_energy = 2.4
