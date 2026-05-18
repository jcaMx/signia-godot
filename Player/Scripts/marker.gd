extends Marker2D

@export var speed = 120

var waypoints = []
var current_index = 0

var last_direction = Vector2.DOWN

@onready var sprite = $AnimatedSprite2D


func _ready():
	waypoints = get_parent().get_node("Waypoints").get_children()


func _process(delta):

	# Stop if finished all waypoints
	if current_index >= waypoints.size():
		play_idle_animation()
		return

	var target = waypoints[current_index].global_position
	var direction = (target - global_position).normalized()

	last_direction = direction

	# Move manually (NO physics)
	global_position += direction * speed * delta

	update_animation(direction)

	# Switch waypoint
	if global_position.distance_to(target) < 5:
		current_index += 1


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
