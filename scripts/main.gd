extends Node

func _ready():
	_load_initial_scene.call_deferred()


func _load_initial_scene():
	var requested_chapter := _get_requested_chapter()

	if LevelManager.level_scenes.has(requested_chapter):
		LevelManager.current_level = requested_chapter
		get_tree().change_scene_to_file.call_deferred(LevelManager.get_current_level_scene())
	else:
		get_tree().change_scene_to_file.call_deferred("res://Scenes/UI/MainMenu.tscn")


func _get_requested_chapter() -> int:
	return LevelManager.check_web_launch_chapter()
