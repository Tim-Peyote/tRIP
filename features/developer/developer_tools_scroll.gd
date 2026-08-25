class_name DeveloperToolsScroll
extends ScrollContainer


func _get_minimum_size() -> Vector2:
	# ScrollContainer otherwise propagates the complete tool list height through
	# nested containers, expanding the developer panel far beyond small viewports.
	return Vector2(0.0, 150.0)
