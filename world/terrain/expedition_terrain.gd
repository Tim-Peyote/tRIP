class_name ExpeditionTerrain
extends StaticBody3D

const PHASE_ORDINARY: StringName = &"ordinary"
const PHASE_MYCELIAL: StringName = &"mycelial"
const MIN_EXPEDITION_Z: float = 5.8

@export_range(16.0, 64.0, 1.0) var chunk_size: float = 30.0
@export_range(9, 49, 2) var chunk_resolution: int = 25
@export_range(1, 4, 1) var active_radius: int = 2
@export_range(1, 4, 1) var chunks_per_frame: int = 1
@export var base_seed: int = 61937

var _run_seed: int = 0
var _world_phase: StringName = PHASE_ORDINARY
var _phase_definition: WorldPhaseDefinition
var _phase_amount: float = 0.0
var _target: Node3D
var _last_center := Vector2i(999999, 999999)
var _chunks: Dictionary[Vector2i, StaticBody3D] = {}
var _pending: Array[Vector2i] = []
var _noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _terrain_material: ShaderMaterial


func _ready() -> void:
	add_to_group(&"terrain_height_provider")
	_configure_noise()
	_terrain_material = _build_terrain_material()
	_refresh_chunks(Vector3(0, 0, 15), true)
	set_process(true)


func setup(target: Node3D) -> void:
	_target = target
	if is_instance_valid(_target):
		_refresh_chunks(_target.global_position, true)


func ensure_area_at(world_position: Vector3) -> void:
	_refresh_chunks(world_position, true)


func set_run_seed(value: int) -> void:
	if _run_seed == value:
		return
	_run_seed = value
	_configure_noise()
	_rebuild_loaded_chunks()


func set_world_phase(value: StringName) -> void:
	if value != PHASE_MYCELIAL:
		value = PHASE_ORDINARY
	if _world_phase == value:
		return
	_world_phase = value
	var tween := create_tween()
	tween.tween_method(_set_phase_amount, _phase_amount, 1.0 if value == PHASE_MYCELIAL else 0.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_rebuild_loaded_decor()


func apply_world_phase(definition: WorldPhaseDefinition) -> void:
	if definition == null:
		return
	_phase_definition = definition
	var next_phase := PHASE_ORDINARY if definition.is_baseline() else definition.id
	if _world_phase == next_phase:
		return
	_world_phase = next_phase
	if _terrain_material != null:
		_terrain_material.set_shader_parameter(&"phase_low", definition.stone_low)
		_terrain_material.set_shader_parameter(&"phase_high", definition.beacon_color)
	var tween := create_tween()
	tween.tween_method(_set_phase_amount, _phase_amount, 0.0 if definition.is_baseline() else 1.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_rebuild_loaded_decor()


func get_world_phase() -> StringName:
	return _world_phase


func get_loaded_chunk_count() -> int:
	return _chunks.size()


func get_height_at_global(world_position: Vector3) -> float:
	return _height_at(world_position.x, world_position.z)


func _process(_delta: float) -> void:
	if is_instance_valid(_target):
		var center := _chunk_coordinate(_target.global_position)
		if center != _last_center:
			_refresh_chunks(_target.global_position, true)
	for _index in mini(chunks_per_frame, _pending.size()):
		var coordinate: Vector2i = _pending.pop_front()
		if not _chunks.has(coordinate):
			_build_chunk(coordinate)


func _set_phase_amount(value: float) -> void:
	_phase_amount = value
	if _terrain_material != null:
		_terrain_material.set_shader_parameter(&"metamorphosis", value)


func _configure_noise() -> void:
	_noise.seed = base_seed * 1000003 + _run_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.0075
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 5
	_noise.fractal_lacunarity = 2.08
	_noise.fractal_gain = 0.48
	_detail_noise.seed = _noise.seed + 7919
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail_noise.frequency = 0.035
	_detail_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_detail_noise.fractal_octaves = 3


func _refresh_chunks(world_position: Vector3, immediate_center: bool) -> void:
	var center := _chunk_coordinate(world_position)
	_last_center = center
	var desired: Dictionary[Vector2i, bool] = {}
	var offsets: Array[Vector2i] = []
	for z_offset in range(-active_radius, active_radius + 1):
		for x_offset in range(-active_radius, active_radius + 1):
			offsets.append(Vector2i(x_offset, z_offset))
	offsets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.length_squared() < b.length_squared())
	_pending.clear()
	for offset: Vector2i in offsets:
		var coordinate := center + offset
		desired[coordinate] = true
		if not _chunks.has(coordinate):
			_pending.append(coordinate)
	for coordinate: Vector2i in _chunks.keys():
		if not desired.has(coordinate):
			_chunks[coordinate].queue_free()
			_chunks.erase(coordinate)
	if immediate_center and not _chunks.has(center):
		_pending.erase(center)
		_build_chunk(center)


func _chunk_coordinate(world_position: Vector3) -> Vector2i:
	return Vector2i(floori(world_position.x / chunk_size), floori(world_position.z / chunk_size))


func _build_chunk(coordinate: Vector2i) -> void:
	var body := StaticBody3D.new()
	body.name = "LandscapeChunk_%d_%d" % [coordinate.x, coordinate.y]
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta(&"landscape_chunk", true)
	add_child(body)
	var mesh := _build_chunk_mesh(coordinate)
	if mesh.get_surface_count() > 0:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Terrain"
		mesh_instance.mesh = mesh
		mesh_instance.material_override = _terrain_material
		body.add_child(mesh_instance)
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		collision.shape = mesh.create_trimesh_shape()
		body.add_child(collision)
	_build_chunk_decor(body, coordinate)
	_chunks[coordinate] = body


func _build_chunk_mesh(coordinate: Vector2i) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var step := chunk_size / float(chunk_resolution - 1)
	var start_x := float(coordinate.x) * chunk_size
	var start_z := float(coordinate.y) * chunk_size
	for z_index in chunk_resolution:
		for x_index in chunk_resolution:
			var x := start_x + float(x_index) * step
			var z := start_z + float(z_index) * step
			var height := _height_at(x, z)
			vertices.append(Vector3(x, height, z))
			var left := _height_at(x - step, z)
			var right := _height_at(x + step, z)
			var back := _height_at(x, z - step)
			var front := _height_at(x, z + step)
			var normal := Vector3(left - right, step * 2.0, back - front).normalized()
			normals.append(normal)
			colors.append(_terrain_color(Vector2(x, z), height, 1.0 - normal.y))
	for z_index in chunk_resolution - 1:
		for x_index in chunk_resolution - 1:
			var world_z := start_z + float(z_index) * step
			if world_z < MIN_EXPEDITION_Z:
				continue
			var current := z_index * chunk_resolution + x_index
			indices.append_array(PackedInt32Array([current, current + chunk_resolution, current + 1, current + 1, current + chunk_resolution, current + chunk_resolution + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if not indices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _height_at(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var macro := _noise.get_noise_2d(x, z) * 11.0
	var ridges := absf(_detail_noise.get_noise_2d(x * 0.42 + 90.0, z * 0.42 - 40.0)) * 4.2
	var height := macro + ridges - 1.5
	var wandering_center := sin(z * 0.018 + float(_run_seed % 97)) * 18.0
	height -= (1.0 - smoothstep(4.0, 15.0, absf(x - wandering_center))) * 3.4
	height = _blend_disc(height, point, Vector2(0, 15), 11.0, 0.0)
	height = _blend_corridor(height, point, Vector2(0, 17), Vector2(0, 49), 4.4, 0.0, 0.35)
	height = _blend_disc(height, point, Vector2(25, 15), 13.0, 0.1)
	var camp_center := Vector2(31.5, 20.5)
	height = lerpf(height, 1.65, 1.0 - smoothstep(4.8, 10.5, point.distance_to(camp_center)))
	var ramp_start := Vector2(20.5, 17.0)
	var ramp_end := Vector2(29.5, 20.0)
	var ramp_distance := _distance_to_segment(point, ramp_start, ramp_end)
	height = lerpf(height, lerpf(0.1, 1.55, _segment_progress(point, ramp_start, ramp_end)), 1.0 - smoothstep(2.0, 4.5, ramp_distance))
	return height


func _terrain_color(point: Vector2, height: float, slope: float) -> Color:
	var color := Color(0.105, 0.205, 0.085).lerp(Color(0.31, 0.29, 0.13), clampf((height + 3.0) / 15.0, 0.0, 1.0))
	var trail := 1.0 - smoothstep(1.15, 3.1, _distance_to_segment(point, Vector2(0, 17), Vector2(0, 49)))
	color = color.lerp(Color(0.31, 0.19, 0.075), trail * 0.72)
	var grove := 1.0 - smoothstep(10.0, 25.0, point.distance_to(Vector2(27, 17)))
	color = color.lerp(Color(0.075, 0.23, 0.18), grove * 0.45)
	return color.lerp(Color(0.31, 0.265, 0.2), smoothstep(0.12, 0.38, slope))


func _build_chunk_decor(body: StaticBody3D, coordinate: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(coordinate)
	var biome := _biome_for_chunk(coordinate)
	_add_tree_multimeshes(body, coordinate, rng, 18 if biome == 0 else 12, biome)
	_add_rock_multimesh(body, coordinate, rng, 10 if biome != 2 else 18)
	if abs(int(_chunk_seed(coordinate))) % 7 == 0:
		_add_point_of_interest(body, coordinate, rng, biome)
	if _is_altered_phase() and abs(int(_chunk_seed(coordinate))) % 3 == 0:
		_add_mycelial_beacon(body, coordinate, rng)


func _add_tree_multimeshes(body: Node3D, coordinate: Vector2i, rng: RandomNumberGenerator, count: int, biome: int) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.38
	trunk.height = 5.2
	trunk.radial_segments = 7
	trunk.material = _standard_material(Color(0.24, 0.095, 0.035))
	var crown: PrimitiveMesh
	match biome:
		0:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 1.45
			cone.height = 2.4
			cone.radial_segments = 8
			crown = cone
		1, 2:
			var sphere := SphereMesh.new()
			sphere.radius = 1.35
			sphere.height = 2.15 if biome == 1 else 1.55
			sphere.radial_segments = 8
			sphere.rings = 4
			crown = sphere
		3:
			var ring := TorusMesh.new()
			ring.inner_radius = 0.55
			ring.outer_radius = 1.35
			ring.rings = 10
			ring.ring_segments = 7
			crown = ring
		_:
			var shard := PrismMesh.new()
			shard.size = Vector3(1.8, 3.2, 1.5)
			crown = shard
	crown.material = _standard_material(Color(0.11, 0.34, 0.1) if biome != 2 else Color(0.24, 0.16, 0.42))
	var trunks := _new_multimesh(trunk, count)
	var crown_layers := 3 if biome == 0 else 2
	var crowns := _new_multimesh(crown, count * crown_layers)
	var placed := 0
	for _attempt in count * 5:
		if placed >= count:
			break
		var point := _random_chunk_point(coordinate, rng)
		if _is_reserved(point):
			continue
		var size := rng.randf_range(0.75, 1.65)
		var ground := _height_at(point.x, point.y)
		var yaw := rng.randf_range(0.0, TAU)
		trunks.set_instance_transform(placed, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(size, size, size)), Vector3(point.x, ground + 2.6 * size, point.y)))
		trunks.set_instance_color(placed, Color(0.18, 0.065, 0.025).lerp(Color(0.36, 0.16, 0.05), rng.randf()))
		for layer in crown_layers:
			var crown_scale := size * (1.15 - float(layer) * 0.2)
			var offset := Vector3(0, size * (4.0 + float(layer) * 1.2), 0)
			if biome != 0:
				offset += Vector3(cos(yaw + layer * PI), 0, sin(yaw + layer * PI)) * size * 0.65
			crowns.set_instance_transform(placed * crown_layers + layer, Transform3D(Basis(Vector3.UP, yaw + layer * 0.3).scaled(Vector3(crown_scale, size, crown_scale)), Vector3(point.x, ground, point.y) + offset))
			var ordinary := Color(0.055, 0.24, 0.075).lerp(Color(0.4, 0.55, 0.12), rng.randf_range(0.0, 0.65))
			var altered_low := _phase_definition.canopy_low if _phase_definition != null else Color(0.15, 0.05, 0.32)
			var altered_high := _phase_definition.canopy_high if _phase_definition != null else Color(0.95, 0.12, 0.62)
			var altered := altered_low.lerp(altered_high, rng.randf_range(0.15, 0.8))
			crowns.set_instance_color(placed * crown_layers + layer, altered if _is_altered_phase() else ordinary)
		placed += 1
	trunks.instance_count = placed
	crowns.instance_count = placed * crown_layers
	_add_multimesh_instance(body, "TreeTrunks", trunks)
	_add_multimesh_instance(body, "TreeCrowns", crowns)


func _add_rock_multimesh(body: Node3D, coordinate: Vector2i, rng: RandomNumberGenerator, count: int) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.9
	mesh.height = 1.35
	mesh.radial_segments = 7
	mesh.rings = 3
	mesh.material = _standard_material(Color(0.26, 0.28, 0.24))
	var multimesh := _new_multimesh(mesh, count)
	for index in count:
		var point := _random_chunk_point(coordinate, rng)
		var size := rng.randf_range(0.4, 1.9)
		var ground := _height_at(point.x, point.y)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.0, TAU), rng.randf_range(-0.2, 0.2))).scaled(Vector3(size * rng.randf_range(0.8, 1.5), size * rng.randf_range(0.45, 0.9), size))
		multimesh.set_instance_transform(index, Transform3D(basis, Vector3(point.x, ground + size * 0.42, point.y)))
		var ordinary := Color(0.19, 0.24, 0.2).lerp(Color(0.48, 0.42, 0.28), rng.randf())
		var altered_low := _phase_definition.stone_low if _phase_definition != null else Color(0.08, 0.32, 0.42)
		var altered_high := _phase_definition.stone_high if _phase_definition != null else Color(0.7, 0.16, 0.65)
		var altered := altered_low.lerp(altered_high, rng.randf())
		multimesh.set_instance_color(index, altered if _is_altered_phase() else ordinary)
	_add_multimesh_instance(body, "BoulderField", multimesh)


func _add_point_of_interest(body: Node3D, coordinate: Vector2i, rng: RandomNumberGenerator, biome: int) -> void:
	var center := Vector2((float(coordinate.x) + 0.5) * chunk_size, (float(coordinate.y) + 0.5) * chunk_size)
	if _is_reserved(center):
		return
	var root := Node3D.new()
	root.name = "GeneratedPOI"
	body.add_child(root)
	var count := 5 + rng.randi_range(0, 4)
	for index in count:
		var shard := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(rng.randf_range(0.7, 1.5), rng.randf_range(3.5, 8.0), rng.randf_range(0.8, 1.8))
		mesh.material = _standard_material(Color(0.25, 0.28, 0.24) if biome != 2 else Color(0.18, 0.12, 0.34), _is_altered_phase())
		shard.mesh = mesh
		var angle := TAU * float(index) / float(count) + rng.randf_range(-0.25, 0.25)
		var radius := rng.randf_range(2.0, 5.5)
		var point := center + Vector2(cos(angle), sin(angle)) * radius
		shard.position = Vector3(point.x, _height_at(point.x, point.y) + mesh.size.y * 0.45, point.y)
		shard.rotation.y = -angle
		root.add_child(shard)
	root.set_meta(&"poi_kind", &"stone_crown")


func _add_mycelial_beacon(body: Node3D, coordinate: Vector2i, rng: RandomNumberGenerator) -> void:
	var center := Vector2((float(coordinate.x) + rng.randf_range(0.25, 0.75)) * chunk_size, (float(coordinate.y) + rng.randf_range(0.25, 0.75)) * chunk_size)
	if _is_reserved(center):
		return
	var beacon := MeshInstance3D.new()
	beacon.name = "MycelialBeacon"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.1
	mesh.outer_radius = 1.45
	mesh.rings = 12
	mesh.ring_segments = 8
	mesh.material = _standard_material(_phase_definition.beacon_color if _phase_definition != null else Color(0.9, 0.08, 0.62), true)
	beacon.mesh = mesh
	beacon.position = Vector3(center.x, _height_at(center.x, center.y) + 2.5, center.y)
	beacon.rotation.x = PI * 0.5
	body.add_child(beacon)


func _random_chunk_point(coordinate: Vector2i, rng: RandomNumberGenerator) -> Vector2:
	return Vector2((float(coordinate.x) + rng.randf_range(0.04, 0.96)) * chunk_size, (float(coordinate.y) + rng.randf_range(0.04, 0.96)) * chunk_size)


func _is_reserved(point: Vector2) -> bool:
	if is_instance_valid(_target):
		var target_point := Vector2(_target.global_position.x, _target.global_position.z)
		if point.distance_to(target_point) < 8.5:
			return true
	if point.y < MIN_EXPEDITION_Z + 2.0:
		return true
	if point.distance_to(Vector2(0, 15)) < 9.0:
		return true
	if _distance_to_segment(point, Vector2(0, 17), Vector2(0, 49)) < 3.4:
		return true
	if point.distance_to(Vector2(25, 15)) < 11.0:
		return true
	if point.distance_to(Vector2(60, 15)) < 10.0:
		return true
	return false


func _biome_for_chunk(coordinate: Vector2i) -> int:
	if _is_altered_phase():
		return _phase_definition.geometry_family if _phase_definition != null else 2
	return 0 if _noise.get_noise_2d(float(coordinate.x) * 19.0, float(coordinate.y) * 19.0) < 0.16 else 1


func _is_altered_phase() -> bool:
	return _world_phase != PHASE_ORDINARY


func _chunk_seed(coordinate: Vector2i) -> int:
	return int(base_seed) * 73856093 ^ int(_run_seed) * 19349663 ^ coordinate.x * 83492791 ^ coordinate.y * 2971215073


func _rebuild_loaded_chunks() -> void:
	var coordinates: Array[Vector2i] = []
	coordinates.assign(_chunks.keys())
	for coordinate: Vector2i in coordinates:
		_chunks[coordinate].queue_free()
	_chunks.clear()
	_pending = coordinates


func _rebuild_loaded_decor() -> void:
	for coordinate: Vector2i in _chunks:
		var body := _chunks[coordinate]
		for child: Node in body.get_children():
			if child.name != "Terrain" and child.name != "Collision":
				child.queue_free()
		_build_chunk_decor(body, coordinate)


func _new_multimesh(mesh: Mesh, count: int) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	return multimesh


func _add_multimesh_instance(parent: Node3D, node_name: String, multimesh: MultiMesh) -> void:
	if multimesh.instance_count == 0:
		return
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.visibility_range_end = chunk_size * float(active_radius + 1)
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(instance)


func _standard_material(color: Color, emission: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.2
	return material


func _build_terrain_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform float metamorphosis : hint_range(0.0, 1.0) = 0.0;
uniform vec3 phase_low : source_color = vec3(0.025, 0.16, 0.32);
uniform vec3 phase_high : source_color = vec3(0.82, 0.025, 0.7);
varying float pulse;
void vertex() {
	float wave_a = sin(VERTEX.x * 0.075 + TIME * 0.65);
	float wave_b = cos(VERTEX.z * 0.061 - TIME * 0.48);
	pulse = wave_a * wave_b;
	VERTEX.y += pulse * 0.32 * metamorphosis;
}
void fragment() {
	vec3 mundane = COLOR.rgb;
	float bands = 0.5 + 0.5 * sin((VERTEX.x + VERTEX.z) * 0.09 + pulse * 2.0);
	vec3 altered = mix(phase_low, phase_high, bands);
	ALBEDO = mix(mundane, altered, metamorphosis * 0.96);
	ROUGHNESS = mix(0.96, 0.62, metamorphosis);
	EMISSION = altered * metamorphosis * (0.3 + max(pulse, 0.0) * 0.45);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"metamorphosis", _phase_amount)
	return material


func _blend_disc(current: float, point: Vector2, center: Vector2, radius: float, target_height: float) -> float:
	var blend := 1.0 - smoothstep(radius * 0.58, radius, point.distance_to(center))
	return lerpf(current, target_height, blend)


func _blend_corridor(current: float, point: Vector2, start: Vector2, end: Vector2, width: float, start_height: float, end_height: float) -> float:
	var blend := 1.0 - smoothstep(width * 0.55, width, _distance_to_segment(point, start, end))
	return lerpf(current, lerpf(start_height, end_height, _segment_progress(point, start, end)), blend)


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var t := clampf((point - start).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
	return point.distance_to(start + segment * t)


func _segment_progress(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	return clampf((point - start).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
