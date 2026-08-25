class_name InventorySpecimenList
extends ItemList

var preview_icon: Texture2D
var preview_title: String


func configure_drag_preview(icon_texture: Texture2D, title: String) -> void:
	preview_icon = icon_texture
	preview_title = title


func _get_drag_data(at_position: Vector2) -> Variant:
	var index := get_item_at_position(at_position, true)
	if index < 0:
		return null
	var payload: Variant = get_item_metadata(index)
	if not payload is Dictionary:
		return null
	select(index)
	item_selected.emit(index)
	var label := Label.new()
	label.custom_minimum_size = Vector2(250.0, 44.0)
	label.text = "%s · %s" % [preview_title, get_item_text(index)]
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color("dce7c8"))
	set_drag_preview(label)
	return (payload as Dictionary).duplicate(true)
