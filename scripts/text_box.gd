extends Control

@export var min_content_width := 48.0
@export var max_content_width := 220.0

@onready var background: NinePatchRect = $NinePatchRect
@onready var margin_container: MarginContainer = $MarginContainer
@onready var speaker_label: Label = $MarginContainer/VBoxContainer/SpeakerLabel
@onready var dialogue_label: Label = $MarginContainer/VBoxContainer/DialogueLabel


func _ready():
	_update_layout.call_deferred()


func set_content(speaker: String, text: String):
	speaker_label.text = speaker
	dialogue_label.text = text
	_update_layout.call_deferred()


func _update_layout():
	if not is_node_ready():
		return

	var target_width = _get_target_content_width()
	speaker_label.custom_minimum_size = Vector2.ZERO
	dialogue_label.custom_minimum_size = Vector2(target_width, 0.0)

	margin_container.custom_minimum_size = Vector2.ZERO
	background.custom_minimum_size = Vector2.ZERO
	custom_minimum_size = Vector2.ZERO

	margin_container.reset_size()
	background.reset_size()
	reset_size()

	await get_tree().process_frame

	var bubble_size = margin_container.get_combined_minimum_size()
	background.custom_minimum_size = bubble_size
	custom_minimum_size = bubble_size
	pivot_offset = bubble_size * 0.5


func _get_target_content_width() -> float:
	return clamp(_get_label_text_width(dialogue_label), min_content_width, max_content_width)


func _get_label_text_width(label: Label) -> float:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")

	if font == null:
		return 0.0

	return ceil(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)


func _gui_input(event: InputEvent):
	if not DialogueManager.active:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not DialogueManager.can_accept_advance_input():
			accept_event()
			return

		DialogueManager.advance()
		accept_event()
