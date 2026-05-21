extends Control

@export var horizontal_padding := 12.0
@export var min_content_width := 260.0
@export var max_content_width := 420.0

@onready var background: NinePatchRect = $NinePatchRect
@onready var margin_container: MarginContainer = $MarginContainer
@onready var content_label: Label = $MarginContainer/NarrationLabel


func _ready():
	_update_layout.call_deferred()


func set_content(text: String, available_width: float = -1.0):
	content_label.text = text
	if available_width > 0.0:
		max_content_width = max(min_content_width, available_width - (horizontal_padding * 2.0))
	_update_layout.call_deferred()


func _update_layout():
	if not is_node_ready():
		return

	var target_width = _get_target_content_width()
	content_label.custom_minimum_size = Vector2(target_width, 0.0)

	var margins = Vector2(
		margin_container.get_theme_constant("margin_left") + margin_container.get_theme_constant("margin_right"),
		margin_container.get_theme_constant("margin_top") + margin_container.get_theme_constant("margin_bottom")
	)
	var total_size = content_label.get_combined_minimum_size() + margins

	custom_minimum_size = total_size
	size = total_size
	background.size = total_size
	margin_container.size = total_size
	pivot_offset = total_size * 0.5


func _get_target_content_width() -> float:
	return clamp(_get_label_text_width(content_label), min_content_width, max_content_width)


func _get_label_text_width(label: Label) -> float:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")

	if font == null:
		return 0.0

	return ceil(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x)


func _gui_input(event: InputEvent):
	if not DialogueManager.active:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not DialogueManager.can_accept_advance_input():
			accept_event()
			return

		DialogueManager.advance()
		accept_event()
