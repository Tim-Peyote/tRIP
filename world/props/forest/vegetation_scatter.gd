class_name VegetationScatter
extends Node3D

@export var area_size: Vector2 = Vector2(17.0, 17.0)
@export_range(0, 1000, 1) var grass_count: int = 240
@export_range(0, 300, 1) var fern_count: int = 56
@export var random_seed: int = 44017
@export_range(0.0, 4.0, 0.1) var trail_half_width: float = 1.15

var _run_seed: int = 0


func _ready() -> void:
	_rebuild()


func set_run_seed(value: int) -> void:
	if _run_seed == value:
		return
	_run_seed = value
	_rebuild()


func _rebuild() -> void:
	for child: Node in get_children():
		if child.has_meta(&"generated_vegetation"):
			child.free()
	_build_grass()
	_build_ferns()


func _build_grass() -> void:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.065, 0.0, 0.0),
		Vector3(0.065, 0.0, 0.0),
		Vector3(0.035, 0.24, 0.0),
		Vector3(0.0, 0.43, 0.0),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.35
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	mesh.surface_set_material(0, material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = grass_count * 2
	var rng := RandomNumberGenerator.new()
	rng.seed = int(random_seed) * 1000003 + int(_run_seed)
	for index in grass_count:
		var position := _sample_position(rng)
		var height := rng.randf_range(0.55, 1.35)
		var yaw := rng.randf_range(0.0, TAU)
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(rng.randf_range(0.7, 1.25), height, 1.0))
		multimesh.set_instance_transform(index * 2, Transform3D(basis, position))
		multimesh.set_instance_transform(index * 2 + 1, Transform3D(Basis(Vector3.UP, yaw + PI * 0.5).scaled(Vector3(rng.randf_range(0.7, 1.25), height, 1.0)), position))
		var tone := Color(rng.randf_range(0.045, 0.1), rng.randf_range(0.13, 0.27), rng.randf_range(0.035, 0.085), 1)
		multimesh.set_instance_color(index * 2, tone)
		multimesh.set_instance_color(index * 2 + 1, tone)
	var instance := MultiMeshInstance3D.new()
	instance.name = "GrassMultiMesh"
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_meta(&"generated_vegetation", true)
	add_child(instance)


func _build_ferns() -> void:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.52, 0.035, 0.95)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.roughness = 1.0
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = fern_count
	var rng := RandomNumberGenerator.new()
	rng.seed = int(random_seed + 991) * 1000003 + int(_run_seed)
	for index in fern_count:
		var position := _sample_position(rng) + Vector3.UP * 0.18
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.65, 1.25))
		multimesh.set_instance_transform(index, Transform3D(basis, position))
		multimesh.set_instance_color(index, Color(rng.randf_range(0.055, 0.12), rng.randf_range(0.17, 0.32), rng.randf_range(0.055, 0.12), 1))
	var instance := MultiMeshInstance3D.new()
	instance.name = "FernMultiMesh"
	instance.multimesh = multimesh
	instance.set_meta(&"generated_vegetation", true)
	add_child(instance)


func _sample_position(rng: RandomNumberGenerator) -> Vector3:
	for _attempt in 12:
		var candidate := Vector3(rng.randf_range(-area_size.x * 0.5, area_size.x * 0.5), 0.14, rng.randf_range(-area_size.y * 0.5, area_size.y * 0.5))
		if absf(candidate.x) > trail_half_width or candidate.z > 3.5:
			return candidate
	return Vector3(rng.randf_range(-area_size.x * 0.5, area_size.x * 0.5), 0.14, rng.randf_range(-area_size.y * 0.5, area_size.y * 0.5))
