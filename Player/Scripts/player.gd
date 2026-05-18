extends CharacterBody2D

@export var speed = 120
@export var loop_path = false

var waypoints = []
var current_index = 0
var last_direction = Vector2.DOWN
var can_move = true

@onready var sprite = $AnimatedSprite2D


func _ready():

	# Get all waypoint nodes
	waypoints = get_parent().get_node("Waypoints").get_children()

	# Prevent errors if no waypoints exist
	if waypoints.is_empty():
		print("No waypoints found!")


func _physics_process(delta):
	if !can_move:
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
	if global_position.distance_to(target) < 5:
		current_index += 1


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

func _input(event):

	if event.is_action_pressed("interact"):

		var npcs = get_tree().get_nodes_in_group("npc")

		for npc in npcs:

			if npc.player_inside:

				can_move = false

				print("Start Dialogue")
