extends Node2D

@export_file("*.json") var dialogue_file
@export var require_continue_input_after_dialogue := false
@export var dialogue_anchor_offset := Vector2(0, -72)

@onready var area: Area2D = $Sprite2D/Area2D


func _ready():
	if area == null:
		push_error("%s is missing its Area2D trigger." % name)
		return

	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)


func _on_body_entered(body):
	if DialogueManager.active:
		return

	if body == null or not (body is CharacterBody2D):
		return

	var dialogue_path = String(dialogue_file)
	if dialogue_path.is_empty():
		push_warning("%s has no dialogue file assigned." % name)
		return

	DialogueManager.start(dialogue_path, self, require_continue_input_after_dialogue)


func get_dialogue_anchor_position() -> Vector2:
	return global_position + dialogue_anchor_offset
