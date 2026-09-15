extends CanvasLayer

var color_rect: ColorRect

signal fade_out_finished
signal fade_in_finished


func _ready():
	layer = 100 # High z-index so it sits above all UI and game elements
	process_mode = Node.PROCESS_MODE_ALWAYS # Allows animation while paused

	color_rect = ColorRect.new()
	color_rect.color = Color.BLACK
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.modulate.a = 0.0
	add_child(color_rect)


## Smoothly fades the screen to black
func fade_to_black(duration := 1.0):
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, duration)
	await tween.finished
	fade_out_finished.emit()


## Smoothly fades the screen back to transparent
func fade_from_black(duration := 1.0):
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 0.0, duration)
	await tween.finished
	fade_in_finished.emit()


## Fades out to black, switches the active scene, then fades back in
func change_scene_with_fade(target_scene_path: String, fade_out_time := 1.0, fade_in_time := 1.0):
	await fade_to_black(fade_out_time)
	get_tree().change_scene_to_file(target_scene_path)
	await fade_from_black(fade_in_time)
