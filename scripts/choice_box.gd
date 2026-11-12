extends Control

@export_group("Debug Configuration")
## When enabled (true), choice buttons can be clicked with the mouse (useful for debugging/testing without camera/gestures).
## When disabled (false), choices are display-only prompts (players must perform the sign language gesture).
@export var is_clickable: bool = false:
	set(value):
		is_clickable = value
		_update_buttons_clickability()

@onready var container: HBoxContainer = $VBoxContainer

var choice_item_scene = preload("res://Scenes/choice_item.tscn")


func _ready():
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	_check_web_debug_override()
	if not GameManager.choice_clickability_changed.is_connected(_on_clickability_changed):
		GameManager.choice_clickability_changed.connect(_on_clickability_changed)
	_update_buttons_clickability()


func is_effective_clickable() -> bool:
	return is_clickable or GameManager.debug_clickable_choices


func _on_clickability_changed(_new_state: bool):
	_update_buttons_clickability()


func _check_web_debug_override():
	if OS.has_feature("web"):
		var url_override = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('debug_choices')")
		if url_override != null:
			var s = str(url_override).to_lower()
			if s in ["1", "true", "yes"]:
				GameManager.debug_clickable_choices = true
			elif s in ["0", "false", "no"]:
				GameManager.debug_clickable_choices = false


func show_choices(choices: Array):
	for child in container.get_children():
		child.queue_free()

	if choices.is_empty():
		hide()
		return

	show()

	var clickable = is_effective_clickable()
	for i in range(choices.size()):
		var choice = choices[i]
		var button = choice_item_scene.instantiate()
		button.set_choice_text(String(choice.get("text", "Choice")))
		if button.has_method("set_clickable"):
			button.set_clickable(clickable)
		else:
			button.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW

		button.pressed.connect(_on_choice_pressed.bind(i))
		container.add_child(button)

	_refresh_size.call_deferred()


func _update_buttons_clickability():
	if container == null:
		return
	var clickable = is_effective_clickable()
	for child in container.get_children():
		if child is Button:
			if child.has_method("set_clickable"):
				child.set_clickable(clickable)
			else:
				child.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
				child.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW


func _on_choice_pressed(choice_index: int):
	if not is_effective_clickable():
		return

	var node = DialogueManager.get_current_node()
	if node.is_empty():
		return

	var choices = node.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return

	var choice = choices[choice_index]
	if typeof(choice) != TYPE_DICTIONARY:
		return

	GameManager.select_choice(choice)


func _refresh_size():
	var content_size = container.get_combined_minimum_size()
	custom_minimum_size = content_size
	size = content_size
