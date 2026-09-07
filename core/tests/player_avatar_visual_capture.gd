extends Node3D

const OUTPUT_PATH := "/tmp/trip_player_avatar_capture.png"


func _ready() -> void:
	var avatar := (load("res://assets/models/actors/geo_researcher.glb") as PackedScene).instantiate()
	avatar.name = "GEOPlayerAvatar"
	avatar.scale = Vector3.ONE
	add_child(avatar)
	var animation_player := avatar.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var crouch_capture := "--crouch" in OS.get_cmdline_user_args()
	animation_player.play(&"Human Armature|CrouchIdle" if crouch_capture else &"Human Armature|Walk")
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(12.0, 12.0)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.11, 0.16, 0.12)
	floor.material_override = floor_material
	add_child(floor)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.8, -0.65, 0.0)
	light.light_energy = 1.45
	light.shadow_enabled = true
	add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.0, 2.0, 2.5)
	fill.light_color = Color(0.28, 0.46, 0.62)
	fill.omni_range = 8.0
	fill.light_energy = 1.4
	add_child(fill)
	var camera := Camera3D.new()
	camera.position = Vector3(3.2, 1.45, 3.8)
	camera.fov = 44.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.92, 0.0), Vector3.UP)
	camera.current = true
	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color(0.025, 0.035, 0.04)
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color(0.22, 0.27, 0.24)
	environment_resource.ambient_light_energy = 0.65
	environment.environment = environment_resource
	add_child(environment)
	await get_tree().create_timer(0.35).timeout
	var error := get_viewport().get_texture().get_image().save_png("/tmp/trip_crouch_capture.png" if crouch_capture else OUTPUT_PATH)
	if error == OK: print("Player avatar capture saved: %s" % OUTPUT_PATH)
	get_tree().quit(error)
