class_name TripUITheme
extends RefCounted

const INK := Color("101713")
const INK_DEEP := Color("080c0a")
const BONE := Color("e8eadf")
const MUTED := Color("99a395")
const MOSS := Color("b7d36f")
const EMBER := Color("ef7a42")


static func build() -> Theme:
	var result := Theme.new()
	result.default_font_size = 15
	result.set_color("font_color", "Label", BONE)
	result.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.72))
	result.set_constant("shadow_offset_x", "Label", 1)
	result.set_constant("shadow_offset_y", "Label", 2)
	result.set_color("font_color", "Button", BONE)
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_pressed_color", "Button", INK_DEEP)
	result.set_color("font_focus_color", "Button", Color.WHITE)
	result.set_color("font_disabled_color", "Button", Color(0.55, 0.58, 0.54, 0.48))
	result.set_font_size("font_size", "Button", 16)
	result.set_constant("outline_size", "Button", 0)
	result.set_stylebox("normal", "Button", _box(Color(0.035, 0.055, 0.045, 0.82), Color(0.42, 0.5, 0.39, 0.42), 1, 8, 14))
	result.set_stylebox("hover", "Button", _box(Color(0.13, 0.19, 0.14, 0.96), MOSS, 1, 8, 14))
	result.set_stylebox("focus", "Button", _box(Color(0.11, 0.17, 0.12, 0.98), MOSS, 2, 8, 14))
	result.set_stylebox("pressed", "Button", _box(MOSS, MOSS, 1, 8, 14))
	result.set_stylebox("disabled", "Button", _box(Color(0.03, 0.04, 0.035, 0.55), Color(0.2, 0.23, 0.2, 0.32), 1, 8, 14))
	result.set_stylebox("panel", "PanelContainer", _box(Color(0.025, 0.04, 0.032, 0.94), Color(0.43, 0.54, 0.4, 0.48), 1, 12, 18))
	result.set_stylebox("background", "ProgressBar", _box(Color(0.015, 0.025, 0.02, 0.86), Color(0.27, 0.33, 0.27, 0.54), 1, 4, 0))
	result.set_stylebox("fill", "ProgressBar", _box(MOSS, MOSS, 0, 4, 0))
	result.set_stylebox("slider", "HSlider", _box(Color(0.16, 0.21, 0.17, 1), Color.TRANSPARENT, 0, 3, 0))
	result.set_stylebox("grabber_area", "HSlider", _box(Color(0.12, 0.16, 0.13, 1), Color(0.3, 0.38, 0.31, 0.7), 1, 4, 0))
	result.set_stylebox("grabber_area_highlight", "HSlider", _box(Color(0.18, 0.25, 0.19, 1), MOSS, 1, 4, 0))
	result.set_color("font_color", "RichTextLabel", BONE)
	result.set_color("default_color", "RichTextLabel", BONE)
	result.set_color("font_outline_color", "RichTextLabel", Color(0, 0, 0, 0.7))
	result.set_constant("outline_size", "RichTextLabel", 1)
	return result


static func make_glass_panel(accent: Color = MOSS, opacity: float = 0.9) -> StyleBoxFlat:
	return _box(Color(0.018, 0.03, 0.024, opacity), Color(accent.r, accent.g, accent.b, 0.46), 1, 10, 14)


static func make_key_chip() -> StyleBoxFlat:
	return _box(Color(0.72, 0.83, 0.44, 0.95), Color(0.9, 0.96, 0.72, 0.9), 1, 6, 8)


static func make_inventory_panel() -> StyleBoxFlat:
	var style := _box(Color(0.012, 0.02, 0.016, 0.985), Color(0.46, 0.58, 0.39, 0.72), 1, 18, 22)
	style.shadow_color = Color(0, 0, 0, 0.78)
	style.shadow_size = 28
	style.shadow_offset = Vector2(0, 10)
	return style


static func make_inventory_slot(state: StringName, accent: Color = MOSS) -> StyleBoxFlat:
	match state:
		&"hover":
			return _box(Color(0.085, 0.12, 0.092, 0.98), Color(accent.r, accent.g, accent.b, 0.9), 1, 12, 8)
		&"selected":
			return _box(Color(0.11, 0.16, 0.105, 1.0), accent.lightened(0.1), 2, 12, 8)
		&"pressed":
			return _box(Color(accent.r * 0.34, accent.g * 0.34, accent.b * 0.34, 1.0), accent, 2, 12, 8)
		_:
			return _box(Color(0.026, 0.04, 0.031, 0.96), Color(0.31, 0.37, 0.31, 0.62), 1, 12, 8)


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
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style
