extends CanvasLayer

@onready var play_button: Button = %PlayButton
@onready var quit_button: Button = %QuitButton
@onready var continue_button: Button = %ContinueButton


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	continue_button.pressed.connect(_on_continue_pressed)

	var has_save = SaveManager.load_game()
	continue_button.disabled = not has_save

	if get_tree().current_scene == self:
		open_menu()
	else:
		hide()


func open_menu():
	show()
	get_tree().paused = true


func close_menu():
	hide()
	get_tree().paused = false


func _on_play_pressed():
	if get_tree().current_scene == self:
		LevelManager.current_level = 1
		var current_volume = SaveManager.save_data.get("volume", 1.0)
		SaveManager.save_data = {
			"current_level": 1,
			"unlocked_level": 1,
			"waypoint_index": 0,
			"completed_levels": [],
			"completed_tasks": [],
			"volume": current_volume
		}
		SaveManager.save_game()
		
		get_tree().paused = false
		get_tree().change_scene_to_file(
			LevelManager.get_current_level_scene()
		)
	else:
		close_menu()


func _on_continue_pressed():
	if get_tree().current_scene == self:
		LevelManager.current_level = SaveManager.save_data.get("unlocked_level", 1)
		get_tree().paused = false
		get_tree().change_scene_to_file(
			LevelManager.get_current_level_scene()
		)


func _on_quit_pressed():
	get_tree().quit()
