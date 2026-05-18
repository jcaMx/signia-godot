extends CanvasLayer

@onready var label = $DialogueUI/Label
@onready var choices_box = $DialogueUI/ChoiceContainer


func _ready():
	DialogueManager.dialogue_updated.connect(update_ui)
	DialogueManager.dialogue_ended.connect(hide_ui)

	hide()


func update_ui(text, choices):
	show()

	label.text = text

	# clear old buttons
	for c in choices_box.get_children():
		c.queue_free()

	# create new choices
	for i in choices.size():
		var btn = Button.new()
		btn.text = choices[i]["text"]

		btn.pressed.connect(func():
			DialogueManager.choose(i)
		)

		choices_box.add_child(btn)


func hide_ui():
	hide()
