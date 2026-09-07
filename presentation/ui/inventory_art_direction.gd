@tool
extends PanelContainer
## A single palette source for this screen, including authored overrides.
func _ready() -> void:
	add_theme_stylebox_override("panel", TripUITheme.make_inventory_panel())
	if not Engine.is_editor_hint():
		$Margin/Layout/Header/Close.pressed.connect(func():
			get_parent().call("_toggle_inventory")
		)
	for node in find_children("*", "Label", true, false):
		var label := node as Label
		label.add_theme_color_override("font_color", TripUITheme.BONE)
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
		if label.name in [&"Subtitle", &"Hint", &"InventoryItemCount", &"QualityTitle", &"FreshnessTitle", &"InventoryMassCaption", &"InventoryVolumeCaption"]:
			label.add_theme_color_override("font_color", TripUITheme.MUTED)
	for node in $Margin/Layout/FilterBar.get_children():
		if node is Button and not node is OptionButton:
			for state in [&"normal", &"hover", &"focus", &"pressed", &"hover_pressed"]:
				node.add_theme_stylebox_override(state, TripUITheme.make_inventory_tab(&"selected" if state in [&"pressed", &"hover_pressed"] else state))
			for color_name in [&"font_color", &"font_pressed_color", &"font_hover_pressed_color"]:
				node.add_theme_color_override(color_name, TripUITheme.BONE)
	$Margin/Layout/Body/Detail.add_theme_stylebox_override("panel", TripUITheme.make_inventory_detail_panel())
	# Actions are a fixed footer outside the scrolling description.
	for button in [$Margin/Layout/Header/Close,
		$Margin/Layout/Body/Detail/DetailMargin/DetailLayout/InventoryActions/InventoryUseButton,
		$Margin/Layout/Body/Detail/DetailMargin/DetailLayout/InventoryActions/InventoryDropButton]:
		for state in [&"normal", &"hover", &"focus", &"pressed", &"disabled"]:
			button.add_theme_stylebox_override(state, TripUITheme.make_inventory_tab(state))
		button.add_theme_color_override("font_color", TripUITheme.BONE)
		button.add_theme_color_override("font_hover_color", TripUITheme.BONE)
		button.add_theme_color_override("font_disabled_color", TripUITheme.MUTED.darkened(0.3))
