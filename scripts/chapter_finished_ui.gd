extends CanvasLayer

@onready var panel = $Panel
@onready var title_label = $Panel/Label
@onready var replay_button = $Panel/Button

var bg_overlay: ColorRect


func _ready():
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

	bg_overlay = ColorRect.new()
	bg_overlay.color = Color(0.04, 0.08, 0.10, 0.90)
	bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg_overlay)
	move_child(bg_overlay, 0)

	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	replay_button.text = "Play Again"
	GameManager.chapter_finished.connect(_on_chapter_finished)
	replay_button.pressed.connect(_on_replay_pressed)


func _on_chapter_finished(level_id):
	var active_level = level_id
	if LevelManager.current_level > 0:
		active_level = LevelManager.current_level
	elif get_tree().current_scene != null:
		var scene_file = get_tree().current_scene.scene_file_path.get_file()
		if scene_file.contains("scene_"):
			var num_str = scene_file.replace("scene_", "").replace(".tscn", "")
			if num_str.is_valid_int():
				active_level = int(num_str)

	title_label.text = "Chapter %d complete" % active_level
	show()
	var pause_menu = get_node_or_null("../PauseMenu")
	if pause_menu != null:
		pause_menu.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().paused = true


func _on_replay_pressed():
	replay_button.disabled = true
	SaveManager.prepare_chapter_restart()
	get_tree().paused = false
	get_tree().reload_current_scene()
