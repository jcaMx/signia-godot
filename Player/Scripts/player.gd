extends CharacterBody2D

@export var speed = 120
@export var loop_path = false

var waypoints = []
var current_index = 0
var last_direction = Vector2.DOWN
var can_move = true
var waiting_for_continue_input := false

@onready var sprite = $AnimatedSprite2D


func _ready():
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

	# Get all waypoint nodes
	waypoints = get_parent().get_node("Waypoints").get_children()

	# Prevent errors if no waypoints exist
	if waypoints.is_empty():
		print("No waypoints found!")


func _physics_process(_delta):
	_advance_waypoint_if_reached()

	if DialogueManager.active or waiting_for_continue_input or not can_move:
		velocity = Vector2.ZERO
		play_idle_animation()
		move_and_slide()
		return
	# Stop if there are no waypoints
	if waypoints.is_empty():
		velocity = Vector2.ZERO
		play_idle_animation()
		move_and_slide()
		return

	# Finished all waypoints
	if current_index >= waypoints.size():

		# Loop back to start
		if loop_path:
			current_index = 0

		# Stop movement
		else:
			velocity = Vector2.ZERO
			play_idle_animation()
			move_and_slide()
			return

	# Current target waypoint
	var target = waypoints[current_index].global_position

	# Direction to target
	var direction = (target - global_position).normalized()

	# Save last movement direction
	last_direction = direction

	# Movement
	velocity = direction * speed

	move_and_slide()

	# Animation
	update_animation(direction)

	# Check if waypoint reached
	_advance_waypoint_if_reached()


func _advance_waypoint_if_reached():
	if waypoints.is_empty():
		return

	if current_index >= waypoints.size():
		return

	var target = waypoints[current_index].global_position
	if global_position.distance_to(target) < 5:
		current_index += 1


func _unhandled_input(event):
	if not waiting_for_continue_input:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		waiting_for_continue_input = false
		DialogueManager.consume_player_continue_request()
		get_viewport().set_input_as_handled()


func _on_dialogue_ended():
	if DialogueManager.should_wait_for_player_continue():
		waiting_for_continue_input = true


func update_animation(direction):

	# Horizontal movement
	if abs(direction.x) > abs(direction.y):

		if direction.x > 0:
			sprite.play("walk_right")
		else:
			sprite.play("walk_left")

	# Vertical movement
	else:

		if direction.y > 0:
			sprite.play("walk_down")
		else:
			sprite.play("walk_up")


func play_idle_animation():

	# Horizontal idle
	if abs(last_direction.x) > abs(last_direction.y):

		if last_direction.x > 0:
			sprite.play("idle_right")
		else:
			sprite.play("idle_left")

	# Vertical idle
	else:

		if last_direction.y > 0:
			sprite.play("idle_down")
		else:
			sprite.play("idle_up")
