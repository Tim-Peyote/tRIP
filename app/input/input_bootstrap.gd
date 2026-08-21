class_name InputBootstrap
extends RefCounted

const JOY_MOTION_BINDINGS: Dictionary = {
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	&"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	&"look_left": [JOY_AXIS_RIGHT_X, -1.0],
	&"look_right": [JOY_AXIS_RIGHT_X, 1.0],
	&"look_up": [JOY_AXIS_RIGHT_Y, -1.0],
	&"look_down": [JOY_AXIS_RIGHT_Y, 1.0],
}

const JOY_BUTTON_BINDINGS: Dictionary = {
	&"interact": JOY_BUTTON_A,
	&"inspect": JOY_BUTTON_X,
	&"inventory": JOY_BUTTON_Y,
	&"journal": JOY_BUTTON_LEFT_SHOULDER,
	&"map": JOY_BUTTON_RIGHT_SHOULDER,
	&"pause": JOY_BUTTON_START,
	&"sprint": JOY_BUTTON_LEFT_STICK,
	&"crouch": JOY_BUTTON_RIGHT_STICK,
	&"quick_use": JOY_BUTTON_DPAD_DOWN,
	&"alternate": JOY_BUTTON_B,
	&"quick_tool": JOY_BUTTON_DPAD_RIGHT,
	&"throw_distraction": JOY_BUTTON_DPAD_LEFT,
	&"road_laboratory": JOY_BUTTON_DPAD_UP,
}


static func ensure_defaults() -> void:
	for action: StringName in JOY_MOTION_BINDINGS:
		_ensure_action(action)
		if not _has_joy_motion(action):
			var binding: Array = JOY_MOTION_BINDINGS[action]
			var event := InputEventJoypadMotion.new()
			event.axis = int(binding[0]) as JoyAxis
			event.axis_value = float(binding[1])
			InputMap.action_add_event(action, event)
	for action: StringName in JOY_BUTTON_BINDINGS:
		_ensure_action(action)
		if not _has_joy_button(action):
			var event := InputEventJoypadButton.new()
			event.button_index = int(JOY_BUTTON_BINDINGS[action]) as JoyButton
			InputMap.action_add_event(action, event)


static func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.15)


static func _has_joy_motion(action: StringName) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			return true
	return false


static func _has_joy_button(action: StringName) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			return true
	return false
