extends CanvasLayer

const TEXTBOX_MARGIN := Vector2(0, -10)
const CHOICEBOX_MARGIN := Vector2(0, 10)
const NARRATOR_SIDE_MARGIN := 18.0
const NARRATOR_BOTTOM_MARGIN := 14.0

var narrator_box_scene = preload("res://Scenes/narrator_box.tscn")

@onready var textbox = $TextBox
@onready var choicebox = $ChoiceBox
@onready var narrator_box = get_node_or_null("NarratorBox")
@onready var main_menu = get_node_or_null("MainMenu")
@onready var pause_menu = get_node_or_null("PauseMenu")
@onready var chapter_finished = get_node_or_null("ChapterFinished")


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

	var anchor_position = speaker_node.global_position
	if speaker_node.has_method("get_dialogue_anchor_position"):
		anchor_position = speaker_node.get_dialogue_anchor_position()

	var screen_position = viewport.get_canvas_transform() * anchor_position
	textbox.position = screen_position - Vector2(textbox.size.x * 0.5, textbox.size.y) + TEXTBOX_MARGIN
	choicebox.position = Vector2(
		screen_position.x - choicebox.size.x * 0.5,
		textbox.position.y + textbox.size.y + CHOICEBOX_MARGIN.y
	)


func _update_narrator_positions():
	var viewport = get_viewport()
	if viewport == null:
		return

	var visible_rect = viewport.get_visible_rect()
	var center_x = visible_rect.position.x + visible_rect.size.x * 0.5
	var base_y = visible_rect.position.y + visible_rect.size.y - narrator_box.size.y - NARRATOR_BOTTOM_MARGIN

	narrator_box.position = Vector2(center_x - narrator_box.size.x * 0.5, base_y)
	choicebox.position = Vector2(
		center_x - choicebox.size.x * 0.5,
		narrator_box.position.y + narrator_box.size.y + CHOICEBOX_MARGIN.y
	)


func _sync_visible_boxes():
	var narrator_mode = DialogueManager.is_current_node_narrator()
	textbox.visible = not narrator_mode
	if narrator_box != null:
		narrator_box.visible = narrator_mode
	if choicebox != null and choicebox.container != null:
		choicebox.visible = choicebox.container.get_child_count() > 0
