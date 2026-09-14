extends CanvasLayer

@onready var input_label = $Panel/CurrentInputLabel
@onready var status_label = $Panel/StatusLabel
@export var keyboard_debug_enabled := true

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
	status_label.text = GameManager.status_message
	input_label.text = GameManager.get_display_input()
