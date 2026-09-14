extends CanvasLayer

@onready var panel = $Panel
@onready var title_label = $Panel/Label
@onready var continue_button = $Panel/Button


func _ready():
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

	GameManager.chapter_finished.connect(_on_chapter_finished)
	continue_button.pressed.connect(_on_continue_pressed)


func _on_chapter_finished(level_id):
	title_label.text = "Chapter %s Finished!" % level_id
	show()
	get_tree().paused = true


func _on_continue_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")
