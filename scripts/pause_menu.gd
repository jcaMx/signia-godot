extends CanvasLayer

@onready var panel = $Panel
@onready var pause_container = get_node_or_null("Panel/PauseContainer")
@onready var settings_container = get_node_or_null("Panel/SettingsContainer")

@onready var resume_button = get_node_or_null("%ResumeButton")
@onready var settings_button = get_node_or_null("%SettingsButton")
@onready var restart_button = get_node_or_null("%RestartButton")
@onready var main_menu_button = get_node_or_null("%MainMenuButton")

@onready var volume_label = get_node_or_null("%VolumeLabel")
@onready var volume_slider = get_node_or_null("%VolumeSlider")
@onready var volume_down_button = get_node_or_null("%VolumeDownButton")
@onready var volume_up_button = get_node_or_null("%VolumeUpButton")
@onready var settings_back_button = get_node_or_null("%SettingsBackButton")

@onready var main_menu = get_node_or_null("../MainMenu")


func _ready():
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

	if resume_button != null:
		resume_button.pressed.connect(_on_resume_pressed)
	if settings_button != null:
		settings_button.pressed.connect(_on_settings_button_pressed)
	if restart_button != null:
		restart_button.pressed.connect(_on_restart_pressed)
	if main_menu_button != null:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	if settings_back_button != null:
		settings_back_button.pressed.connect(_on_settings_back_pressed)

	if volume_down_button != null:
		volume_down_button.pressed.connect(_on_volume_down_pressed)
	if volume_up_button != null:
		volume_up_button.pressed.connect(_on_volume_up_pressed)

	# Initialize slider value based on current audio server volume
	var current_db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	var current_vol = db_to_linear(current_db)
	if volume_slider != null:
		volume_slider.value = current_vol
		volume_slider.value_changed.connect(_on_volume_changed)

	_update_volume_label(current_vol)
	show_pause_container()


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
	show_pause_container()
	show()
	get_tree().paused = true


func open_settings():
	show_settings_container()
	show()
	get_tree().paused = true


func resume_game():
	hide()
	get_tree().paused = false


func show_pause_container():
	if pause_container != null:
		pause_container.show()
	if settings_container != null:
		settings_container.hide()


func show_settings_container():
	if pause_container != null:
		pause_container.hide()
	if settings_container != null:
		settings_container.show()


func _on_resume_pressed():
	resume_game()


func _on_settings_button_pressed():
	show_settings_container()


func _on_settings_back_pressed():
	show_pause_container()


func _on_restart_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_main_menu_pressed():
	hide()
	if main_menu != null and main_menu.has_method("open_menu"):
		main_menu.open_menu()
	else:
		push_warning("PauseMenu could not find a MainMenu sibling to reopen.")


func _on_volume_down_pressed():
	if volume_slider != null:
		volume_slider.value = clamp(volume_slider.value - 0.1, 0.0, 1.0)


func _on_volume_up_pressed():
	if volume_slider != null:
		volume_slider.value = clamp(volume_slider.value + 0.1, 0.0, 1.0)


func _on_volume_changed(value: float):
	var db_val = linear_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db_val)
	_update_volume_label(value)
	if SaveManager != null and "save_data" in SaveManager and SaveManager.save_data is Dictionary:
		SaveManager.save_data["volume"] = value
		if SaveManager.has_method("save_game"):
			SaveManager.save_game()


func _update_volume_label(value: float):
	if volume_label != null:
		volume_label.text = "Volume: %d%%" % int(round(value * 100))


func _is_main_menu_open() -> bool:
	return main_menu != null and main_menu.visible
