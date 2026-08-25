class_name ExpeditionMapView
extends Control

signal full_map_changed(is_open: bool)

const MINI_SIZE := Vector2(184.0, 184.0)
const MINI_RANGE: float = 105.0
const INK := Color("dfe6cf")
const MUTED := Color("92a08a")
const ACCENT := Color("c3d978")
const UNKNOWN := Color(0.015, 0.025, 0.022, 0.88)

var _exploration: MapExplorationOrchestrator
var _terrain: ExpeditionTerrain
var _player: Node3D
var _phases: WorldPhaseOrchestrator
var _full_open: bool = false
var _minimap_suppressed: bool = false
var _redraw_elapsed: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func setup(exploration: MapExplorationOrchestrator, terrain: ExpeditionTerrain, player: Node3D, phases: WorldPhaseOrchestrator) -> void:
	_exploration = exploration
	_terrain = terrain
	_player = player
	_phases = phases
	exploration.exploration_changed.connect(func(_phase_id: StringName) -> void: queue_redraw())
	exploration.active_phase_changed.connect(func(_phase_id: StringName) -> void: queue_redraw())
	queue_redraw()


func toggle_full_map() -> void:
	set_full_map_open(not _full_open)


func set_full_map_open(value: bool) -> void:
	if _full_open == value:
		return
	_full_open = value
	mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	full_map_changed.emit(value)


func is_full_map_open() -> bool:
	return _full_open


func set_minimap_suppressed(value: bool) -> void:
	_minimap_suppressed = value
	queue_redraw()


func _process(delta: float) -> void:
	_redraw_elapsed += delta
	if _redraw_elapsed >= 0.16:
		_redraw_elapsed = 0.0
		queue_redraw()


func _draw() -> void:
	if _exploration == null or _terrain == null or not is_instance_valid(_player):
		return
	if _full_open:
		_draw_full_map()
	elif not _minimap_suppressed:
		_draw_minimap()


func _draw_minimap() -> void:
	var rect := Rect2(size.x - MINI_SIZE.x - 28.0, 92.0, MINI_SIZE.x, MINI_SIZE.y)
	_draw_backplate(rect, 0.82)
	var inner := rect.grow(-10.0)
	_draw_cells(inner, Rect2(_player_xz() - Vector2.ONE * MINI_RANGE, Vector2.ONE * MINI_RANGE * 2.0))
	_draw_player_marker(inner.get_center(), _player.rotation.y, 8.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(13.0, 20.0), "РАЗВЕДКА", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, MUTED)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(rect.size.x - 26.0, 20.0), "N", HORIZONTAL_ALIGNMENT_CENTER, 16.0, 12, INK)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(13.0, rect.size.y - 12.0), "M  КАРТА", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color(MUTED, 0.9))


func _draw_full_map() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.006, 0.012, 0.01, 0.94))
	var margin := clampf(size.x * 0.065, 42.0, 112.0)
	var panel := Rect2(Vector2(margin, 34.0), Vector2(size.x - margin * 2.0, size.y - 68.0))
	_draw_backplate(panel, 0.96)
	var header_height := 84.0
	var footer_height := 52.0
	var map_rect := Rect2(panel.position + Vector2(24.0, header_height), panel.size - Vector2(48.0, header_height + footer_height))
	var fitted := map_rect
	var visible_world := _get_explored_window(map_rect.size.x / maxf(map_rect.size.y, 1.0))
	_draw_cells(fitted, visible_world)
	var player_screen := _world_to_screen(_player_xz(), fitted, visible_world)
	_draw_player_marker(player_screen, _player.rotation.y, 11.0)
	var phase_name := "НЕИЗВЕСТНЫЙ СЛОЙ"
	if _phases != null and _phases.get_current() != null:
		phase_name = _phases.get_current().display_name.to_upper()
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(28.0, 38.0), "КАРТА ЭКСПЕДИЦИИ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 25, INK)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(29.0, 64.0), phase_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, ACCENT)
	var ratio := _exploration.get_explored_ratio()
	var explored_text := "ИЗУЧЕНО  %.1f%%" % (ratio * 100.0)
	draw_string(ThemeDB.fallback_font, panel.end - Vector2(190.0, panel.size.y - 46.0), explored_text, HORIZONTAL_ALIGNMENT_RIGHT, 160.0, 13, MUTED)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(28.0, panel.size.y - 20.0), "M  ЗАКРЫТЬ   ·   СВЕТЛЫЕ УЧАСТКИ — ПРОЙДЕННЫЙ ПУТЬ   ·   НЕИЗВЕДАННОЕ НЕ ОТОБРАЖАЕТСЯ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, MUTED)
	draw_string(ThemeDB.fallback_font, fitted.position + Vector2(fitted.size.x - 18.0, 22.0), "N", HORIZONTAL_ALIGNMENT_CENTER, 16.0, 14, INK)


func _draw_cells(screen_rect: Rect2, world_rect: Rect2) -> void:
	draw_rect(screen_rect, UNKNOWN)
	var cells := _exploration.get_explored_cells()
	var cell_size := _exploration.get_cell_size()
	var screen_cell := Vector2(cell_size / world_rect.size.x * screen_rect.size.x, cell_size / world_rect.size.y * screen_rect.size.y)
	for raw_key: Variant in cells:
		var coordinate := _decode_cell(String(raw_key))
		var center := Vector2((coordinate.x + 0.5) * cell_size, (coordinate.y + 0.5) * cell_size)
		if not world_rect.has_point(center):
			continue
		var screen_center := _world_to_screen(center, screen_rect, world_rect)
		if not screen_rect.has_point(screen_center):
			continue
		var sample := cells[raw_key] as Dictionary
		var zone := int(sample.get("zone", ExpeditionTerrain.LandscapeZone.DENSE_FOREST))
		var height := float(sample.get("height", 0.0))
		var color := _zone_color(zone).lightened(clampf(height / 120.0, -0.08, 0.14))
		var tile := Rect2(screen_center - screen_cell * 0.54, screen_cell * 1.08)
		tile = tile.intersection(screen_rect)
		if tile.size.x > 0.0 and tile.size.y > 0.0:
			draw_rect(tile, color)
	# Border masks raw cell edges and anchors the cartographic plane.
	draw_rect(screen_rect, Color(0.45, 0.55, 0.42, 0.34), false, 1.0)


func _draw_backplate(rect: Rect2, alpha: float) -> void:
	draw_rect(rect, Color(0.025, 0.045, 0.037, alpha))
	draw_rect(rect.grow(-1.0), Color(0.55, 0.68, 0.48, 0.42), false, 1.0)


func _draw_player_marker(center: Vector2, yaw: float, radius: float) -> void:
	var forward := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(-forward.y, forward.x)
	var points := PackedVector2Array([
		center + forward * radius,
		center - forward * radius * 0.62 + right * radius * 0.55,
		center - forward * radius * 0.62 - right * radius * 0.55,
	])
	draw_colored_polygon(points, ACCENT)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color("f2f6e7"), 1.2)


func _zone_color(zone: int) -> Color:
	match zone:
		ExpeditionTerrain.LandscapeZone.SHELTER_EDGE:
			return Color("78694d")
		ExpeditionTerrain.LandscapeZone.RIVER_VALLEY:
			return Color("476e68")
		ExpeditionTerrain.LandscapeZone.HIGHLAND:
			return Color("756d55")
		ExpeditionTerrain.LandscapeZone.ALPINE:
			return Color("a8afa4")
		ExpeditionTerrain.LandscapeZone.BASIN:
			return Color("3f6357")
		ExpeditionTerrain.LandscapeZone.BOUNDARY:
			return Color("4e4b45")
		_:
			return Color("405b42")


func _world_to_screen(world: Vector2, screen_rect: Rect2, world_rect: Rect2) -> Vector2:
	var normalized := (world - world_rect.position) / world_rect.size
	return screen_rect.position + Vector2(normalized.x, 1.0 - normalized.y) * screen_rect.size


func _fit_aspect(container: Rect2, aspect: float) -> Rect2:
	var result_size := container.size
	if result_size.x / result_size.y > aspect:
		result_size.x = result_size.y * aspect
	else:
		result_size.y = result_size.x / aspect
	return Rect2(container.get_center() - result_size * 0.5, result_size)


func _get_explored_window(screen_aspect: float) -> Rect2:
	var cells := _exploration.get_explored_cells()
	var cell_size := _exploration.get_cell_size()
	var minimum := _player_xz()
	var maximum := minimum
	for raw_key: Variant in cells:
		var coordinate := _decode_cell(String(raw_key))
		var center := Vector2((coordinate.x + 0.5) * cell_size, (coordinate.y + 0.5) * cell_size)
		minimum = minimum.min(center)
		maximum = maximum.max(center)
	var center := (minimum + maximum) * 0.5
	var extent := maximum - minimum + Vector2.ONE * 112.0
	extent.x = maxf(extent.x, 340.0)
	extent.y = maxf(extent.y, 340.0)
	if extent.x / extent.y < screen_aspect:
		extent.x = extent.y * screen_aspect
	else:
		extent.y = extent.x / screen_aspect
	return Rect2(center - extent * 0.5, extent)


func _player_xz() -> Vector2:
	return Vector2(_player.global_position.x, _player.global_position.z)


func _decode_cell(value: String) -> Vector2i:
	var parts := value.split(":", false, 1)
	return Vector2i(int(parts[0]), int(parts[1])) if parts.size() == 2 else Vector2i.ZERO
