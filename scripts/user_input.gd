extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var input_label: Label = $Panel.find_child("CurrentInputLabel", true, false)
@onready var status_label: Label = $Panel.find_child("StatusLabel", true, false)
@onready var vbox: VBoxContainer = $Panel.find_child("VBoxContainer", true, false)
@export var keyboard_debug_enabled := true

const COLOR_NORMAL := Color.WHITE
const COLOR_ERROR := Color(1.0, 0.35, 0.35)
const COLOR_SUCCESS := Color(0.35, 0.95, 0.45)

const BASE_BOTTOM_Y := 255.0
const MIN_PANEL_HEIGHT := 49.0
const PANEL_PADDING_Y := 12.0

func _ready():
	if not GameManager.word_started.is_connected(_on_word_started):
		GameManager.word_started.connect(_on_word_started)
	if not GameManager.word_progress_changed.is_connected(_on_word_state_changed):
		GameManager.word_progress_changed.connect(_on_word_state_changed)
	if not GameManager.word_cleared.is_connected(_on_word_cleared):
		GameManager.word_cleared.connect(_on_word_cleared)

	_refresh()
	visible = GameManager.has_active_word()


func _unhandled_input(event):
	if not keyboard_debug_enabled:
		return

	if not GameManager.has_active_word():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if GameManager.uses_direct_sign_ui():
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
				GameManager.submit_sign(GameManager.pending_sign_id)
				get_viewport().set_input_as_handled()
			return

		var key_text = OS.get_keycode_string(event.keycode)
		if SignProcessor.normalize_letter_input(key_text).is_empty():
			return

		GameManager.submit_letter(key_text)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if GameManager.uses_direct_sign_ui():
			GameManager.submit_sign(GameManager.pending_sign_id)
			get_viewport().set_input_as_handled()
		return


func _on_word_started(_target_word: String, _sign_id: String):
	if GameManager.has_active_word():
		show()
	else:
		hide()
	_refresh()


func _on_word_state_changed(_target_word: String = "", _current_input: String = "", _status_message: String = ""):
	if GameManager.has_active_word():
		show()
	else:
		hide()
	_refresh()


func _on_word_cleared():
	hide()
	_refresh()


func _refresh():
	var msg: String = GameManager.status_message
	status_label.text = msg
	input_label.text = GameManager.get_display_input()

	if msg.is_empty():
		status_label.add_theme_color_override("font_color", COLOR_NORMAL)
	else:
		var lower_msg := msg.to_lower()
		if lower_msg.contains("error") or lower_msg.contains("incorrect") or lower_msg.contains("wrong") or lower_msg.contains("invalid") or lower_msg.contains("does not match"):
			status_label.add_theme_color_override("font_color", COLOR_ERROR)
		elif lower_msg.contains("correct") or lower_msg.contains("detected"):
			status_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		else:
			status_label.add_theme_color_override("font_color", COLOR_NORMAL)

	_update_panel_layout.call_deferred()


func _update_panel_layout():
	if vbox == null or panel == null:
		return

	var content_height: float = vbox.get_combined_minimum_size().y + PANEL_PADDING_Y
	var new_height: float = max(MIN_PANEL_HEIGHT, content_height)
	panel.offset_top = BASE_BOTTOM_Y - new_height
	panel.offset_bottom = BASE_BOTTOM_Y
