extends CanvasLayer

@onready var panel = $Panel
@onready var resume_button = %ResumeButton
@onready var restart_button = %RestartButton
@onready var main_menu_button = %MainMenuButton
@onready var volume_slider = %VolumeSlider
@onready var main_menu = get_node_or_null("../MainMenu")


func _ready():
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	# Initialize slider value based on current audio server volume
	var current_db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	volume_slider.value = db_to_linear(current_db)
	volume_slider.value_changed.connect(_on_volume_changed)


func _input(event):
	if _is_main_menu_open():
		return

	if event.is_action_pressed("pause"):
		toggle_pause()


func toggle_pause():
	if get_tree().paused:
		resume_game()
	else:
		pause_game()


func pause_game():
	show()
	get_tree().paused = true


func resume_game():
	hide()
	get_tree().paused = false


func _on_resume_pressed():
	resume_game()


func _on_restart_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_main_menu_pressed():
	hide()
	if main_menu != null and main_menu.has_method("open_menu"):
		main_menu.open_menu()
	else:
		push_warning("PauseMenu could not find a MainMenu sibling to reopen.")


func _on_volume_changed(value: float):
	var db_val = linear_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db_val)
	SaveManager.save_data["volume"] = value
	SaveManager.save_game()


func _is_main_menu_open() -> bool:
	return main_menu != null and main_menu.visible
