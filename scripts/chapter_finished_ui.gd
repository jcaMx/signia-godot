extends CanvasLayer

@onready var panel = $Panel
@onready var title_label = $Panel/Label
@onready var continue_button = $Panel/Button

var bg_overlay: ColorRect


func _ready():
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create full-screen semi-transparent dark background overlay (70% opacity black)
	bg_overlay = ColorRect.new()
	bg_overlay.color = Color(0, 0, 0, 0.7)
	bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_overlay)
	move_child(bg_overlay, 0) # Move to back behind panel and text

	GameManager.chapter_finished.connect(_on_chapter_finished)
	continue_button.pressed.connect(_on_continue_pressed)


func _on_chapter_finished(level_id):
	var active_level = level_id
	if get_tree().current_scene != null:
		var scene_file = get_tree().current_scene.scene_file_path.get_file()
		if scene_file.contains("scene_"):
			var num_str = scene_file.replace("scene_", "").replace(".tscn", "")
			if num_str.is_valid_int():
				active_level = int(num_str)

	title_label.text = "Chapter %d Finished!" % active_level
	show()
	get_tree().paused = true


func _on_continue_pressed():
	get_tree().paused = false
	SceneChanger.change_scene_with_fade("res://Scenes/UI/MainMenu.tscn", 1.0, 1.0)
