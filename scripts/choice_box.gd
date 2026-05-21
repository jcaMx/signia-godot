extends Control

@onready var container: HBoxContainer = $VBoxContainer

var choice_item_scene = preload("res://choice_item.tscn")


func show_choices(choices: Array):
	for child in container.get_children():
		child.queue_free()

	if choices.is_empty():
		hide()
		return

	show()

	for i in range(choices.size()):
		var choice = choices[i]
		var button = choice_item_scene.instantiate()
		button.set_choice_text(String(choice.get("text", "Choice")))
		button.pressed.connect(_on_choice_pressed.bind(i))
		container.add_child(button)

	_refresh_size.call_deferred()


func _on_choice_pressed(choice_index: int):
	var node = DialogueManager.get_current_node()
	if node.is_empty():
		return

	var choices = node.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return

	var choice = choices[choice_index]
	if typeof(choice) != TYPE_DICTIONARY:
		return

	GameManager.start_challenge(String(choice.get("sign", "")), choice.get("next", -1))


func _refresh_size():
	var content_size = container.get_combined_minimum_size()
	custom_minimum_size = content_size
	size = content_size
