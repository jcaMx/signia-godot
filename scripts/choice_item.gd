extends Button


func set_choice_text(value: String):
	text = value
	focus_mode = Control.FOCUS_NONE


func set_clickable(clickable: bool):
	mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	tooltip_text = "[Debug] Click to choose" if clickable else ""
