extends SceneTree

func _initialize() -> void:
	var theme := preload("res://presentation/ui/trip_ui_theme.gd").build()
	var error := ResourceSaver.save(theme, "res://presentation/ui/trip_theme.tres")
	print("Shared UI theme export: ", error_string(error))
	quit(error)
