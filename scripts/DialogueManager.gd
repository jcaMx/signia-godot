extends Node

signal dialogue_started
signal dialogue_ended
signal dialogue_updated(text, choices)

var current_dialogue = []
var index = 0
var active = false


func start(dialogue_data: Array):
	current_dialogue = dialogue_data
	index = 0
	active = true

	dialogue_started.emit()
	show_current()


func show_current():
	var node = current_dialogue[index]

	dialogue_updated.emit(node["text"], node["choices"])


func choose(option_index: int):
	var node = current_dialogue[index]

	if option_index >= node["choices"].size():
		return

	var next_index = node["choices"][option_index]["next"]

	if next_index == -1:
		end()
		return

	index = next_index
	show_current()


func end():
	active = false
	dialogue_ended.emit()


func process_sign(sign_id: String):

	var node = current_dialogue[index]
	var choices = node["choices"]

	for choice in choices:

		if choice["sign"] == sign_id:

			var next_index = choice["next"]

			if next_index == -1:
				end()
				return

			index = next_index
			show_current()
			return
