extends CharacterBody2D

@export var speed = 120
@export var loop_path = false
@export var level_id := 1

var waypoints = []
var current_index = 0
var last_direction = Vector2.DOWN
var can_move = true
var waiting_for_continue_input := false
var chapter_finish_triggered := false

@onready var sprite = $AnimatedSprite2D


func _ready():
	SaveManager.restoring = true
	if not SaveManager.has_loaded_initial and not SaveManager.restart_pending:
		SaveManager.load_game()

	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

	var web_chapter = LevelManager.check_web_launch_chapter()
	if web_chapter > 0:
		level_id = web_chapter
	elif get_tree().current_scene != null:
		var scene_file = get_tree().current_scene.scene_file_path.get_file()
		if scene_file.contains("scene_"):
			var num_str = scene_file.replace("scene_", "").replace(".tscn", "")
			if num_str.is_valid_int():
				level_id = int(num_str)

	waypoints = get_parent().get_node("Waypoints").get_children()

	LevelManager.setup_level(level_id, get_parent())

	SaveManager.apply_player_position(self)
	LevelManager.update_waypoint_progress(current_index)
	SaveManager.restore_player.call_deferred(self)

	if waypoints.is_empty():
		print("No waypoints found!")


func _physics_process(_delta):
	if SaveManager.restoring:
		return
	_advance_waypoint_if_reached()

	if DialogueManager.active or waiting_for_continue_input or not can_move:
		velocity = Vector2.ZERO
		play_idle_animation()
		move_and_slide()
		return

	if waypoints.is_empty():
		velocity = Vector2.ZERO
		play_idle_animation()
		move_and_slide()
		return

	if current_index >= waypoints.size():
		if loop_path:
			current_index = 0
		else:
			velocity = Vector2.ZERO
			play_idle_animation()
			move_and_slide()

		if not chapter_finish_triggered:
			chapter_finish_triggered = true
			LevelManager.complete_level()
			GameManager.finish_chapter()

		return

	var target = waypoints[current_index].global_position
	var direction = (target - global_position).normalized()
	last_direction = direction
	velocity = direction * speed

	move_and_slide()
	update_animation(direction)
	_advance_waypoint_if_reached()


func _advance_waypoint_if_reached():
	if waypoints.is_empty():
		return

	if current_index >= waypoints.size():
		return

	var target = waypoints[current_index].global_position

	if global_position.distance_to(target) < 5:
		current_index += 1
		LevelManager.update_waypoint_progress(current_index)
		SaveManager.save_game()


func _on_dialogue_ended():
	waiting_for_continue_input = false
	DialogueManager.consume_player_continue_request()


func update_animation(direction):
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			sprite.play("walk_right")
		else:
			sprite.play("walk_left")
	else:
		if direction.y > 0:
			sprite.play("walk_down")
		else:
			sprite.play("walk_up")


func play_idle_animation():
	if abs(last_direction.x) > abs(last_direction.y):
		if last_direction.x > 0:
			sprite.play("idle_right")
		else:
			sprite.play("idle_left")
	else:
		if last_direction.y > 0:
			sprite.play("idle_down")
		else:
			sprite.play("idle_up")
