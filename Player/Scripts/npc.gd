extends Node2D

@export_file("*.json") var dialogue_file

var dialogue = []

func _ready():
	load_dialogue()


func load_dialogue():
	var file = FileAccess.open(dialogue_file, FileAccess.READ)
	dialogue = JSON.parse_string(file.get_as_text())


func _on_body_entered(body):
	if body.name == "Player":
		body.can_move = false
		DialogueManager.start(dialogue)
