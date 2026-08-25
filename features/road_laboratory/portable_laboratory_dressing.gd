class_name PortableLaboratoryDressing
extends Node3D

const KENNEY := "res://assets/third_party/kenney_survival_kit/"
const LAB := "res://assets/third_party/open_game_art_lab/"

const TENT := preload(KENNEY + "tent-canvas.glb")
const CANVAS := preload(KENNEY + "structure-canvas.glb")
const WORKBENCH := preload(KENNEY + "workbench.glb")
const CAMPFIRE_PIT := preload(KENNEY + "campfire-pit.glb")
const CAMPFIRE_TRIPOD := preload(KENNEY + "campfire-fishing-stand.glb")
const BUCKET := preload(KENNEY + "bucket.glb")
const LARGE_BOTTLE := preload(KENNEY + "bottle-large.glb")
const OPEN_BARREL := preload(KENNEY + "barrel-open.glb")
const OPEN_BOX := preload(KENNEY + "box-open.glb")
const LARGE_OPEN_BOX := preload(KENNEY + "box-large-open.glb")
const BEDROLL := preload(KENNEY + "bedroll-packed.glb")
const FUEL_WOOD := preload(KENNEY + "resource-wood.glb")
const FUEL_STONE := preload(KENNEY + "resource-stone.glb")
const HAMMER := preload(KENNEY + "tool-hammer.glb")
const SHOVEL := preload(KENNEY + "tool-shovel.glb")

const RETORT := preload(LAB + "bottle_glassware_retort_flask_large.glb")
const ERLENMEYER := preload(LAB + "bottle_glassware_erlenmeyer_flask_large.glb")
const TEST_TUBE_RACK := preload(LAB + "bottle_test_tube_rack.glb")
const EVAPORATING_DISH := preload(LAB + "dish_evaporating_dish.glb")
const SEPARATORY_FUNNEL := preload(LAB + "funnel_seperatory_funnel.glb")
const FORCEPS := preload(LAB + "heating_equipment_forceps.glb")
const RING_STAND := preload(LAB + "heating_equipment_ring_stand.glb")
const STIRRING_STICK := preload(LAB + "heating_equipment_stirring_stick.glb")
const THERMOMETER := preload(LAB + "heating_equipment_thermometer.glb")
const MAGNIFIER := preload(LAB + "misc_magnifying_glass.glb")
const BALANCE_SCALE := preload(LAB + "misc_scale.glb")
const WASH_BOTTLE := preload(LAB + "misc_wash_bottle.glb")

var authored_model_count: int = 0


func build(laboratory_root: Node3D) -> void:
	name = "AuthoredLaboratoryDressing"
	laboratory_root.add_child(self)
	_arrange_workflow(laboratory_root)
	_build_camp_silhouette()
	_dress_workbench(laboratory_root)
	_dress_fire_station(laboratory_root)
	_dress_field_tools(laboratory_root)
	_add_small_props()


func _arrange_workflow(root: Node3D) -> void:
	# Preparation and heat occupy separate work zones, so the interaction ray
	# reaches one meaningful object instead of five overlapping placeholders.
	_set_position(root, "Cauldron", Vector3(2.05, 0.43, 0.56))
	_set_position(root, "FireControl", Vector3(2.76, 0.27, 0.76))
	_set_position(root, "PotCrane", Vector3(2.44, 0.36, 0.6))
	_set_position(root, "Bellows", Vector3(3.0, 0.25, 0.72))
	_set_position(root, "CookingStationAudio", Vector3(2.05, 0.34, 0.56))
	var visuals := root.get_node_or_null("CookingStationVisuals") as CookingStationVisuals
	if visuals != null:
		visuals.mortar_contents.position = Vector3(-0.72, 1.275, -2.35)
		visuals.active_liquid.position = Vector3(2.05, 0.735, 0.56)
		visuals.steam.position = Vector3(2.05, 0.78, 0.56)
		visuals.fire_mesh.position = Vector3(2.05, 0.18, 0.56)
		visuals.fire_glow.position = Vector3(2.05, 0.31, 0.56)
		visuals.refresh_rest_transforms()


func _build_camp_silhouette() -> void:
	var tent := _add_model(self, "FieldTent", TENT, Vector3(-3.7, 0.02, -2.75), Vector3(0, 0.34, 0), Vector3.ONE * 5.4)
	_tint_model(tent, Color(0.16, 0.25, 0.17), 0.92)
	_add_static_box("FieldTentCollision", Vector3(-3.7, 0.78, -2.75), Vector3(2.9, 1.55, 1.65), Vector3(0, 0.34, 0))
	var canvas := _add_model(self, "WeatherCanvas", CANVAS, Vector3(0.25, 0.02, -3.25), Vector3(0, -0.04, 0), Vector3.ONE * 4.2)
	_tint_model(canvas, Color(0.2, 0.29, 0.2), 0.9)
	_add_model(self, "PackedBedroll", BEDROLL, Vector3(-2.7, 0.08, -1.25), Vector3(0, -0.6, 0), Vector3.ONE * 3.2)
	var sample_crate := _add_model(self, "SampleCrate", LARGE_OPEN_BOX, Vector3(2.72, 0.05, -1.4), Vector3(0, -0.35, 0), Vector3.ONE * 3.4)
	_tint_model(sample_crate, Color(0.31, 0.18, 0.08), 0.88)
	_add_static_box("SampleCrateCollision", Vector3(2.72, 0.35, -1.4), Vector3(0.72, 0.7, 0.72), Vector3(0, -0.35, 0))
	var tool_crate := _add_model(self, "ToolCrate", OPEN_BOX, Vector3(-2.3, 0.04, -0.76), Vector3(0, 0.45, 0), Vector3.ONE * 2.8)
	_tint_model(tool_crate, Color(0.27, 0.14, 0.055), 0.9)
	_add_static_box("ToolCrateCollision", Vector3(-2.3, 0.28, -0.76), Vector3(0.58, 0.56, 0.58), Vector3(0, 0.45, 0))
	var fuel := _add_model(self, "FuelStack", FUEL_WOOD, Vector3(3.05, 0.05, 1.2), Vector3(0, 0.28, 0), Vector3.ONE * 3.2)
	_tint_model(fuel, Color(0.28, 0.12, 0.045), 0.96)
	var stones := _add_model(self, "HearthStones", FUEL_STONE, Vector3(2.05, 0.01, 0.56), Vector3.ZERO, Vector3.ONE * 3.4)
	_tint_model(stones, Color(0.18, 0.2, 0.19), 0.97)
	_add_model(self, "FieldHammer", HAMMER, Vector3(-2.15, 0.44, -0.76), Vector3(0.2, 0.3, -1.2), Vector3.ONE * 3.0)
	_add_model(self, "FieldShovel", SHOVEL, Vector3(-3.75, 0.05, -2.0), Vector3(0, 0.18, -0.18), Vector3.ONE * 4.5)


func _dress_workbench(root: Node3D) -> void:
	var table := root.get_node_or_null("Table") as Node3D
	if table != null:
		_hide_mesh_children(table)
		var workbench := _add_model(table, "AuthoredWorkbench", WORKBENCH, Vector3(0, -0.93, 0), Vector3.ZERO, Vector3(8.2, 6.4, 5.0))
		_tint_model(workbench, Color(0.25, 0.12, 0.045), 0.87)
	var basin := root.get_node_or_null("WashBasin") as Node3D
	if basin != null:
		_hide_named_mesh(basin, "Bowl")
		var wash_bucket := _add_model(basin, "WashBucket", BUCKET, Vector3(0, -0.11, 0), Vector3.ZERO, Vector3.ONE * 1.45)
		_tint_model(wash_bucket, Color(0.22, 0.26, 0.25), 0.48, 0.35)
		_add_model(basin, "RinseBottle", WASH_BOTTLE, Vector3(0.18, -0.03, 0.05), Vector3.ZERO, Vector3.ONE * 0.34)
	var board := root.get_node_or_null("PrepBoard") as Node3D
	if board != null:
		_add_model(board, "FieldForceps", FORCEPS, Vector3(-0.18, 0.1, 0.04), Vector3(0, 0.25, 0), Vector3.ONE * 0.38)
		_add_model(board, "Magnifier", MAGNIFIER, Vector3(0.16, 0.1, -0.08), Vector3(0, -0.4, 0), Vector3.ONE * 0.32)
	var mortar := root.get_node_or_null("Mortar") as Node3D
	if mortar != null:
		_hide_named_mesh(mortar, "Bowl")
		_add_model(mortar, "StoneMortarBowl", EVAPORATING_DISH, Vector3(0, 0.02, 0), Vector3.ZERO, Vector3.ONE * 0.58)
		_dress_pestle(mortar.get_node_or_null("Pestle") as Node3D)


func _dress_fire_station(root: Node3D) -> void:
	var pit := _add_model(self, "CampfirePit", CAMPFIRE_PIT, Vector3(2.05, 0.01, 0.56), Vector3.ZERO, Vector3.ONE * 4.0)
	_tint_model(pit, Color(0.16, 0.16, 0.145), 0.94)
	var tripod := _add_model(self, "CookingTripod", CAMPFIRE_TRIPOD, Vector3(2.05, 0.02, 0.56), Vector3(0, 0.18, 0), Vector3.ONE * 2.75)
	_tint_model(tripod, Color(0.075, 0.08, 0.075), 0.7, 0.28)
	_build_hearth_embers()
	var cauldron := root.get_node_or_null("Cauldron") as Node3D
	if cauldron != null:
		_hide_named_mesh(cauldron, "Body")
		_hide_named_mesh(cauldron, "Liquid")
		var pot := _add_model(cauldron, "CastIronPot", BUCKET, Vector3(0, -0.36, 0), Vector3.ZERO, Vector3.ONE * 3.2)
		_tint_model(pot, Color(0.055, 0.065, 0.062), 0.68, 0.12)
	var crane := root.get_node_or_null("PotCrane") as Node3D
	if crane != null:
		_hide_named_mesh(crane, "Body")
	var fire_control := root.get_node_or_null("FireControl") as Node3D
	if fire_control != null:
		_hide_named_mesh(fire_control, "Body")
		_build_fire_damper(fire_control)
	var bellows := root.get_node_or_null("Bellows") as Node3D
	if bellows != null:
		_hide_named_mesh(bellows, "Body")
		_build_bellows(bellows)


func _dress_field_tools(root: Node3D) -> void:
	var water_jug := root.get_node_or_null("WaterJug") as Node3D
	if water_jug != null:
		_hide_named_mesh(water_jug, "Body")
		_add_model(water_jug, "WaterCanister", LARGE_BOTTLE, Vector3(0, -0.08, 0), Vector3.ZERO, Vector3.ONE * 3.2)
	var kvass := root.get_node_or_null("KvassJug") as Node3D
	if kvass != null:
		_hide_named_mesh(kvass, "Body")
		_add_model(kvass, "KvassCask", OPEN_BARREL, Vector3(0, -0.08, 0), Vector3.ZERO, Vector3.ONE * 2.5)
	var ladle := root.get_node_or_null("Ladle") as Node3D
	if ladle != null:
		_hide_named_mesh(ladle, "Body")
		_add_model(ladle, "WoodenStirrer", STIRRING_STICK, Vector3.ZERO, Vector3(0, 0, 1.2), Vector3.ONE * 0.75)
	var bottles := root.get_node_or_null("BottleRack") as Node3D
	if bottles != null:
		_add_model(bottles, "GlasswareRack", TEST_TUBE_RACK, Vector3(0.28, -0.12, 0), Vector3.ZERO, Vector3.ONE * 0.42)
	var distiller := root.get_node_or_null("Distiller") as Node3D
	if distiller != null:
		_hide_named_mesh(distiller, "Body")
		_hide_named_mesh(distiller, "Receiver")
		_add_model(distiller, "CopperStand", RING_STAND, Vector3(0, -0.22, 0), Vector3.ZERO, Vector3.ONE * 0.42)
		_add_model(distiller, "Retort", RETORT, Vector3(0.02, 0.03, 0), Vector3(0, -0.35, 0), Vector3.ONE * 0.36)
		_add_model(distiller, "Separator", SEPARATORY_FUNNEL, Vector3(0.3, -0.03, 0), Vector3.ZERO, Vector3.ONE * 0.28)
	var serving := root.get_node_or_null("ServingBowl") as Node3D
	if serving != null:
		_hide_named_mesh(serving, "Body")
		_add_model(serving, "ServingDish", EVAPORATING_DISH, Vector3(0, -0.06, 0), Vector3.ZERO, Vector3.ONE * 0.52)
	var hourglass := root.get_node_or_null("Hourglass") as Node3D
	if hourglass != null:
		_hide_named_mesh(hourglass, "Body")
		_build_hourglass(hourglass)


func _add_small_props() -> void:
	_add_model(self, "BalanceScale", BALANCE_SCALE, Vector3(-1.82, 1.17, -2.34), Vector3.ZERO, Vector3.ONE * 0.34)
	_add_model(self, "Thermometer", THERMOMETER, Vector3(0.58, 0.62, -0.68), Vector3(0, 0, -0.12), Vector3.ONE * 0.38)
	_add_model(self, "ResearchFlask", ERLENMEYER, Vector3(2.34, 1.12, -2.15), Vector3.ZERO, Vector3.ONE * 0.34)
	_build_work_lamp()


func _build_work_lamp() -> void:
	_add_model(self, "OilLampGlass", ERLENMEYER, Vector3(-0.12, 1.08, -2.7), Vector3.ZERO, Vector3.ONE * 0.52)
	var wick_material := _material(Color(0.22, 0.035, 0.008), 0.82)
	wick_material.emission_enabled = true
	wick_material.emission = Color(1.0, 0.24, 0.035)
	wick_material.emission_energy_multiplier = 2.4
	_add_primitive(self, "OilLampFlame", SphereMesh.new(), Vector3(-0.12, 1.26, -2.7), Vector3.ZERO, wick_material, Vector3(0.045, 0.09, 0.045))
	var lamp_light := OmniLight3D.new()
	lamp_light.name = "WorkbenchLampLight"
	lamp_light.position = Vector3(-0.12, 1.32, -2.7)
	lamp_light.light_color = Color(1.0, 0.46, 0.18)
	lamp_light.light_energy = 0.72
	lamp_light.omni_range = 3.2
	lamp_light.shadow_enabled = false
	add_child(lamp_light)


func _dress_pestle(pestle: Node3D) -> void:
	if pestle == null:
		return
	if pestle is MeshInstance3D:
		(pestle as MeshInstance3D).mesh = null
	var stone := _material(Color(0.22, 0.24, 0.2), 0.96)
	_add_primitive(pestle, "PestleHandle", CylinderMesh.new(), Vector3.ZERO, Vector3.ZERO, stone, Vector3(0.13, 0.38, 0.13))
	_add_primitive(pestle, "PestleHead", SphereMesh.new(), Vector3(0, -0.17, 0), Vector3.ZERO, stone, Vector3(0.18, 0.13, 0.18))


func _build_fire_damper(parent: Node3D) -> void:
	var iron := _material(Color(0.08, 0.085, 0.075), 0.72, 0.18)
	var wheel := TorusMesh.new()
	wheel.inner_radius = 0.1
	wheel.outer_radius = 0.135
	wheel.rings = 12
	wheel.ring_segments = 6
	_add_primitive(parent, "DamperWheel", wheel, Vector3.ZERO, Vector3(PI * 0.5, 0, 0), iron)
	_add_primitive(parent, "DamperLever", CylinderMesh.new(), Vector3(0.13, 0, 0), Vector3(0, 0, PI * 0.5), iron, Vector3(0.045, 0.32, 0.045))


func _build_hearth_embers() -> void:
	var ember_material := _material(Color(0.18, 0.025, 0.008), 0.9)
	ember_material.emission_enabled = true
	ember_material.emission = Color(0.95, 0.12, 0.018)
	ember_material.emission_energy_multiplier = 1.65
	for offset: Vector3 in [Vector3(-0.16, 0, -0.06), Vector3(0.02, 0.015, 0.1), Vector3(0.17, 0, -0.04)]:
		_add_primitive(self, "BankedEmber", SphereMesh.new(), Vector3(2.05, 0.16, 0.56) + offset, Vector3.ZERO, ember_material, Vector3(0.09, 0.035, 0.07))
	var glow := OmniLight3D.new()
	glow.name = "BankedEmberGlow"
	glow.position = Vector3(2.05, 0.24, 0.56)
	glow.light_color = Color(1.0, 0.24, 0.07)
	glow.light_energy = 0.28
	glow.omni_range = 1.35
	glow.shadow_enabled = false
	add_child(glow)


func _build_bellows(parent: Node3D) -> void:
	var leather := _material(Color(0.24, 0.095, 0.045), 0.92)
	var wood := _material(Color(0.28, 0.16, 0.075), 0.88)
	var iron := _material(Color(0.09, 0.1, 0.095), 0.64, 0.22)
	var body := PrismMesh.new()
	body.size = Vector3(0.48, 0.18, 0.62)
	_add_primitive(parent, "LeatherBody", body, Vector3.ZERO, Vector3(0, PI * 0.5, 0), leather)
	_add_primitive(parent, "TopBoard", BoxMesh.new(), Vector3(0, 0.12, 0), Vector3.ZERO, wood, Vector3(0.42, 0.055, 0.58))
	_add_primitive(parent, "Nozzle", CylinderMesh.new(), Vector3(-0.34, 0, 0), Vector3(0, 0, PI * 0.5), iron, Vector3(0.09, 0.42, 0.09))


func _build_hourglass(parent: Node3D) -> void:
	var wood := _material(Color(0.3, 0.17, 0.07), 0.84)
	var glass := _material(Color(0.52, 0.72, 0.68, 0.34), 0.12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for y: float in [-0.22, 0.22]:
		_add_primitive(parent, "HourglassPlate", CylinderMesh.new(), Vector3(0, y, 0), Vector3.ZERO, wood, Vector3(0.2, 0.045, 0.2))
	for x: float in [-0.13, 0.13]:
		_add_primitive(parent, "HourglassPost", CylinderMesh.new(), Vector3(x, 0, 0), Vector3.ZERO, wood, Vector3(0.035, 0.42, 0.035))
	var upper := CylinderMesh.new()
	upper.top_radius = 0.13
	upper.bottom_radius = 0.025
	upper.height = 0.19
	upper.radial_segments = 12
	_add_primitive(parent, "UpperGlass", upper, Vector3(0, 0.095, 0), Vector3.ZERO, glass)
	var lower := CylinderMesh.new()
	lower.top_radius = 0.025
	lower.bottom_radius = 0.13
	lower.height = 0.19
	lower.radial_segments = 12
	_add_primitive(parent, "LowerGlass", lower, Vector3(0, -0.095, 0), Vector3.ZERO, glass)


func _add_model(parent: Node3D, model_name: String, scene: PackedScene, position: Vector3, rotation: Vector3, scale: Vector3) -> Node3D:
	var model := scene.instantiate() as Node3D
	model.name = model_name
	model.position = position
	model.rotation = rotation
	# The OGA laboratory pack is authored in centimetres, while Kenney's kit is
	# authored in metres. Keep the conversion at the asset boundary so every
	# station can use readable world-space dimensions.
	model.scale = scale * (0.01 if scene.resource_path.contains("open_game_art_lab") else 1.0)
	parent.add_child(model)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	authored_model_count += 1
	return model


func _add_primitive(parent: Node3D, node_name: String, mesh: PrimitiveMesh, position: Vector3, rotation: Vector3, material: Material, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.position = position
	visual.rotation = rotation
	visual.scale = scale
	visual.material_override = material
	parent.add_child(visual)
	return visual


func _add_static_box(body_name: String, position: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = position
	body.rotation = rotation
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _tint_model(model: Node3D, color: Color, roughness: float, metallic: float = 0.0) -> void:
	var material := _material(color, roughness, metallic)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = material


func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _hide_mesh_children(parent: Node3D) -> void:
	for child: Node in parent.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false


func _hide_named_mesh(parent: Node3D, child_name: String) -> void:
	var child := parent.get_node_or_null(child_name) as MeshInstance3D
	if child != null:
		child.visible = false


func _set_position(root: Node3D, node_name: String, value: Vector3) -> void:
	var target := root.get_node_or_null(node_name) as Node3D
	if target != null:
		target.position = value
