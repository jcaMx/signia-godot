extends Node

signal sign_received(sign_id)

var active = false
var sign_map = {}

func _on_dialogue_start():
	active = true

func _on_dialogue_end():
	active = false


func on_sign_detected(sign_id: String):

	if !active:
		return

	sign_received.emit(sign_id)

	if sign_id in sign_map:
		var choice_index = sign_map[sign_id]
		DialogueManager.choose(choice_index)
		
		
