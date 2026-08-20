class_name VisualProfile
extends ContentDefinition

@export_range(0.0, 1.0, 0.01) var fog_density: float = 0.1
@export var fog_color: Color = Color(0.2, 0.26, 0.2)
@export_range(0.0, 4.0, 0.01) var exposure_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.01) var palette_mix: float = 0.0
@export_range(0.0, 1.0, 0.01) var dither: float = 0.0
@export_range(0.0, 1.0, 0.01) var scanlines: float = 0.0
@export_range(0.0, 1.0, 0.01) var chroma_shift: float = 0.0
@export_range(0.0, 1.0, 0.01) var tracking_tear: float = 0.0
@export_range(0.0, 1.0, 0.01) var affine_wobble: float = 0.0

