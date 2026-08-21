class_name TripUITheme
extends RefCounted

const INK := Color("101713")
const INK_DEEP := Color("080c0a")
const BONE := Color("e8eadf")
const MUTED := Color("a7ad9f")
const MOSS := Color("bfd875")
const EMBER := Color("ef8754")
const SLATE := Color("18201c")
const PAPER := Color("d9ddca")


static func build() -> Theme:
	var result := Theme.new()
	result.default_font_size = 15
	result.set_color("font_color", "Label", BONE)
	result.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.62))
	result.set_constant("shadow_offset_x", "Label", 1)
	result.set_constant("shadow_offset_y", "Label", 2)
	result.set_color("font_color", "Button", BONE)
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_pressed_color", "Button", INK_DEEP)
	result.set_color("font_focus_color", "Button", Color.WHITE)
	result.set_color("font_disabled_color", "Button", Color(0.55, 0.58, 0.54, 0.48))
	result.set_font_size("font_size", "Button", 16)
	result.set_constant("outline_size", "Button", 0)
	result.set_stylebox("normal", "Button", make_button(&"normal"))
	result.set_stylebox("hover", "Button", make_button(&"hover"))
	result.set_stylebox("focus", "Button", make_button(&"focus"))
	result.set_stylebox("pressed", "Button", make_button(&"pressed"))
	result.set_stylebox("hover_pressed", "Button", make_button(&"pressed"))
	result.set_stylebox("disabled", "Button", make_button(&"disabled"))
	result.set_stylebox("panel", "PanelContainer", make_content_panel())
	result.set_stylebox("background", "ProgressBar", _box(Color(0.055, 0.07, 0.06, 0.9), Color(0.42, 0.46, 0.39, 0.3), 1, 5, 0))
	result.set_stylebox("fill", "ProgressBar", _box(MOSS, MOSS, 0, 4, 0))
	result.set_stylebox("slider", "HSlider", _box(Color(0.16, 0.21, 0.17, 1), Color.TRANSPARENT, 0, 3, 0))
	result.set_stylebox("grabber_area", "HSlider", _box(Color(0.12, 0.16, 0.13, 1), Color(0.3, 0.38, 0.31, 0.7), 1, 4, 0))
	result.set_stylebox("grabber_area_highlight", "HSlider", _box(Color(0.18, 0.25, 0.19, 1), MOSS, 1, 4, 0))
	result.set_color("font_color", "RichTextLabel", BONE)
	result.set_color("default_color", "RichTextLabel", BONE)
	result.set_color("font_outline_color", "RichTextLabel", Color(0, 0, 0, 0.7))
	result.set_constant("outline_size", "RichTextLabel", 1)
	result.set_color("font_color", "ItemList", PAPER)
	result.set_color("font_selected_color", "ItemList", Color("101510"))
	result.set_stylebox("panel", "ItemList", _box(Color(0.055, 0.068, 0.058, 0.42), Color(0.65, 0.7, 0.58, 0.14), 1, 9, 8))
	result.set_stylebox("selected", "ItemList", _box(Color(MOSS.r, MOSS.g, MOSS.b, 0.9), MOSS, 0, 7, 8))
	result.set_stylebox("selected_focus", "ItemList", _box(Color(MOSS.r, MOSS.g, MOSS.b, 0.95), Color("ecf7c6"), 1, 7, 8))
	result.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	result.set_stylebox("separator", "HSeparator", _line(Color(0.72, 0.78, 0.63, 0.24), 1))
	result.set_color("font_color", "OptionButton", BONE)
	result.set_font_size("font_size", "OptionButton", 14)
	return result


static func make_glass_panel(accent: Color = MOSS, opacity: float = 0.9) -> StyleBoxFlat:
	var style := _box(Color(0.055, 0.072, 0.061, opacity), Color(accent.r, accent.g, accent.b, 0.4), 1, 12, 14)
	style.border_width_left = 3
	style.border_width_top = 1
	return style


static func make_key_chip() -> StyleBoxFlat:
	return _box(Color(0.75, 0.86, 0.46, 0.98), Color(0.92, 0.97, 0.74, 0.9), 1, 8, 8)


static func make_inventory_panel() -> StyleBoxFlat:
	var style := _box(Color(0.075, 0.09, 0.078, 0.84), Color(0.76, 0.84, 0.61, 0.28), 1, 18, 22)
	style.border_width_top = 2
	style.border_width_left = 1
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 6)
	return style


static func make_modal_panel(accent: Color = MOSS) -> StyleBoxFlat:
	var style := _box(Color(0.105, 0.12, 0.105, 0.95), Color(accent.r, accent.g, accent.b, 0.52), 1, 18, 24)
	style.border_width_top = 3
	style.shadow_color = Color(0, 0, 0, 0.72)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	return style


static func make_content_panel(accent: Color = Color(0.58, 0.65, 0.5), opacity: float = 0.82) -> StyleBoxFlat:
	var style := _box(Color(0.12, 0.14, 0.12, opacity), Color(accent.r, accent.g, accent.b, 0.34), 1, 14, 18)
	style.border_width_top = 1
	style.border_width_left = 2
	return style


static func make_hud_plate(accent: Color = MOSS, align_right: bool = false) -> StyleBoxFlat:
	var style := _box(Color(0.025, 0.035, 0.03, 0.62), Color(accent.r, accent.g, accent.b, 0.42), 0, 8, 10)
	style.border_width_right = 3 if align_right else 0
	style.border_width_left = 0 if align_right else 3
	style.shadow_size = 7
	return style


static func make_button(state: StringName, accent: Color = MOSS) -> StyleBoxFlat:
	match state:
		&"hover":
			var hover := _box(Color(0.13, 0.16, 0.135, 0.96), Color(accent.r, accent.g, accent.b, 0.78), 1, 9, 15)
			hover.border_width_left = 4
			hover.shadow_size = 4
			return hover
		&"focus":
			var focus := _box(Color(0.15, 0.18, 0.145, 0.98), accent, 1, 9, 15)
			focus.border_width_left = 5
			focus.shadow_size = 5
			return focus
		&"pressed":
			return _box(Color(accent.r, accent.g, accent.b, 0.96), accent.lightened(0.12), 1, 9, 15)
		&"disabled":
			return _box(Color(0.065, 0.075, 0.067, 0.44), Color(0.3, 0.32, 0.28, 0.2), 1, 9, 15)
		_:
			var normal := _box(Color(0.075, 0.09, 0.078, 0.74), Color(0.56, 0.62, 0.5, 0.3), 1, 9, 15)
			normal.border_width_left = 2
			return normal


static func make_menu_button(state: StringName) -> StyleBoxFlat:
	var style := make_button(state, EMBER if state == &"pressed" else MOSS)
	style.content_margin_left = 20
	style.content_margin_right = 20
	return style


static func make_inventory_slot(state: StringName, accent: Color = MOSS) -> StyleBoxFlat:
	match state:
		&"hover":
			return _box(Color(0.14, 0.165, 0.14, 0.98), Color(accent.r, accent.g, accent.b, 0.9), 1, 13, 8)
		&"selected":
			return _box(Color(0.17, 0.2, 0.16, 1.0), accent.lightened(0.1), 2, 13, 8)
		&"pressed":
			return _box(Color(accent.r * 0.38, accent.g * 0.38, accent.b * 0.38, 1.0), accent, 2, 13, 8)
		_:
			return _box(Color(0.085, 0.1, 0.087, 0.92), Color(0.55, 0.61, 0.5, 0.36), 1, 13, 8)


static func _line(color: Color, thickness: int) -> StyleBoxLine:
	var style := StyleBoxLine.new()
	style.color = color
	style.thickness = thickness
	style.vertical = false
	return style


static func _box(fill: Color, border: Color, width: int, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = maxi(6, padding / 2)
	style.content_margin_bottom = maxi(6, padding / 2)
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	return style
