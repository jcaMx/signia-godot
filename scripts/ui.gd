extends CanvasLayer

const TEXTBOX_MARGIN := Vector2(0, -10)
const CHOICEBOX_MARGIN := Vector2(0, 8)
const NARRATOR_SIDE_MARGIN := 16.0
const NARRATOR_BOTTOM_MARGIN := 12.0
const SCREEN_PADDING := 8.0

var narrator_box_scene = preload("res://Scenes/narrator_box.tscn")

@onready var textbox = $TextBox
@onready var choicebox = $ChoiceBox
@onready var narrator_box = get_node_or_null("NarratorBox")
@onready var main_menu = get_node_or_null("MainMenu")
@onready var pause_menu = get_node_or_null("PauseMenu")
@onready var chapter_finished = get_node_or_null("ChapterFinished")
@onready var pause_button = get_node_or_null("PauseButton")
@onready var settings_button = get_node_or_null("SettingsButton")


func _ready():
	if get_parent() is CanvasLayer:
		hide()
		return

	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_updated.connect(_on_dialogue_updated)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	textbox.scale = Vector2.ONE
	choicebox.scale = Vector2.ONE
	if narrator_box == null:
		narrator_box = narrator_box_scene.instantiate()
		narrator_box.name = "NarratorBox"
		add_child(narrator_box)
	narrator_box.hide()

	if pause_button != null:
		pause_button.pressed.connect(_on_pause_button_pressed)
	if settings_button != null:
		settings_button.pressed.connect(_on_settings_button_pressed)

	hide()


func _on_dialogue_started():
	show()
	_sync_visible_boxes()
	_update_dialogue_positions()


func _on_dialogue_updated(speaker, text, choices):
	if DialogueManager.is_current_node_narrator():
		var visible_rect = get_viewport().get_visible_rect()
		narrator_box.set_content(text, visible_rect.size.x - (NARRATOR_SIDE_MARGIN * 2.0))
	else:
		textbox.set_content(speaker, text)
	choicebox.show_choices(choices)
	_sync_visible_boxes()
	_update_dialogue_positions.call_deferred()


func _on_dialogue_ended():
	textbox.hide()
	choicebox.hide()
	if narrator_box != null:
		narrator_box.hide()
	hide()


func _process(_delta):
	# Check if any overlay menu is visible
	var menu_open = false
	if main_menu != null and main_menu.visible:
		menu_open = true
	elif pause_menu != null and pause_menu.visible:
		menu_open = true
	elif chapter_finished != null and chapter_finished.visible:
		menu_open = true

	if pause_button != null:
		pause_button.visible = not menu_open
	if settings_button != null:
		settings_button.visible = not menu_open

	if menu_open:
		textbox.hide()
		choicebox.hide()
		if narrator_box != null:
			narrator_box.hide()
		return

	if not visible or not DialogueManager.active:
		return

	_sync_visible_boxes()
	_update_dialogue_positions()


func _on_pause_button_pressed():
	if pause_menu != null and pause_menu.has_method("toggle_pause"):
		pause_menu.toggle_pause()


func _on_settings_button_pressed():
	if pause_menu != null and pause_menu.has_method("open_settings"):
		pause_menu.open_settings()


func _update_dialogue_positions():
	if DialogueManager.is_current_node_narrator():
		_update_narrator_positions()
		return

	var speaker_node = DialogueManager.get_active_speaker_node()
	if speaker_node == null:
		return

	var viewport = get_viewport()
	if viewport == null:
		return

	var screen_size = viewport.get_visible_rect().size

	var anchor_position = speaker_node.global_position
	if speaker_node.has_method("get_dialogue_anchor_position"):
		anchor_position = speaker_node.get_dialogue_anchor_position()

	var screen_position = viewport.get_canvas_transform() * anchor_position

	# Calculate desired position for Speech Textbox
	var tb_x = screen_position.x - textbox.size.x * 0.5
	var tb_y = screen_position.y - textbox.size.y + TEXTBOX_MARGIN.y

	# Clamp Speech Textbox within screen boundaries
	tb_x = clamp(tb_x, SCREEN_PADDING, screen_size.x - textbox.size.x - SCREEN_PADDING)
	tb_y = clamp(tb_y, SCREEN_PADDING, screen_size.y - textbox.size.y - SCREEN_PADDING)
	textbox.position = Vector2(tb_x, tb_y)

	# Position Choice Box relative to Textbox
	if choicebox.visible:
		var cb_x = screen_position.x - choicebox.size.x * 0.5
		var cb_y = textbox.position.y + textbox.size.y + CHOICEBOX_MARGIN.y

		# If Choice Box spills off bottom of screen, flip it above Textbox
		if cb_y + choicebox.size.y > screen_size.y - SCREEN_PADDING:
			cb_y = textbox.position.y - choicebox.size.y - CHOICEBOX_MARGIN.y

		# Clamp Choice Box within screen boundaries
		cb_x = clamp(cb_x, SCREEN_PADDING, screen_size.x - choicebox.size.x - SCREEN_PADDING)
		cb_y = clamp(cb_y, SCREEN_PADDING, screen_size.y - choicebox.size.y - SCREEN_PADDING)
		choicebox.position = Vector2(cb_x, cb_y)


func _update_narrator_positions():
	var viewport = get_viewport()
	if viewport == null:
		return

	var screen_size = viewport.get_visible_rect().size
	var center_x = screen_size.x * 0.5

	# Position Narrator Box anchored near bottom
	var nb_x = clamp(center_x - narrator_box.size.x * 0.5, SCREEN_PADDING, screen_size.x - narrator_box.size.x - SCREEN_PADDING)
	var nb_y = screen_size.y - narrator_box.size.y - NARRATOR_BOTTOM_MARGIN

	# Place Choice Box ABOVE Narrator Box when choices are active
	if choicebox.visible:
		var cb_x = clamp(center_x - choicebox.size.x * 0.5, SCREEN_PADDING, screen_size.x - choicebox.size.x - SCREEN_PADDING)
		var cb_y = nb_y - choicebox.size.y - CHOICEBOX_MARGIN.y

		# If top of choice box goes off top of screen, adjust narrator box down
		if cb_y < SCREEN_PADDING:
			cb_y = SCREEN_PADDING
			nb_y = clamp(cb_y + choicebox.size.y + CHOICEBOX_MARGIN.y, SCREEN_PADDING, screen_size.y - narrator_box.size.y - SCREEN_PADDING)

		choicebox.position = Vector2(cb_x, cb_y)

	narrator_box.position = Vector2(nb_x, nb_y)


func _sync_visible_boxes():
	var narrator_mode = DialogueManager.is_current_node_narrator()
	textbox.visible = not narrator_mode
	if narrator_box != null:
		narrator_box.visible = narrator_mode
	if choicebox != null and choicebox.container != null:
		choicebox.visible = choicebox.container.get_child_count() > 0
