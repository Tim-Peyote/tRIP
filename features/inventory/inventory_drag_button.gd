class_name InventoryDragButton
extends Button

var drag_payload: Dictionary = {}
var preview_icon: Texture2D
var preview_title: String


func configure_drag(payload: Dictionary, icon_texture: Texture2D, title: String) -> void:
	drag_payload = payload.duplicate(true)
	preview_icon = icon_texture
	preview_title = title


func _get_drag_data(_at_position: Vector2) -> Variant:
	if drag_payload.is_empty():
		return null
	button_pressed = true
	pressed.emit()
	set_drag_preview(_make_preview())
	return drag_payload.duplicate(true)


func _make_preview() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(190.0, 58.0)
	panel.add_theme_stylebox_override("panel", TripUITheme.make_inventory_slot(&"selected", TripUITheme.MOSS))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon_view := TextureRect.new()
	icon_view.custom_minimum_size = Vector2(46.0, 46.0)
	icon_view.texture = preview_icon
	icon_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon_view)
	var label := Label.new()
	label.text = preview_title
	label.add_theme_color_override("font_color", TripUITheme.BONE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return panel
