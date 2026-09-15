extends Node

signal progress_changed(current_index, total_count)
signal level_completed(level_id)

var current_level := 1

var level_scenes := {
	1: "res://Scenes/scene_1.tscn",
	2: "res://Scenes/scene_2.tscn",
	3: "res://Scenes/scene_3.tscn"
}


func get_current_level_scene() -> String:
	return level_scenes.get(current_level, level_scenes[1])
	
var current_waypoint_index := 0
var total_waypoints := 0


func setup_level(level_id: int, waypoint_count: int):
	current_level = level_id
	total_waypoints = waypoint_count
	current_waypoint_index = 0
	GameManager.chapter_is_finished = false
	DialogueManager.end()
	GameManager.cancel_word()
	progress_changed.emit(current_waypoint_index, total_waypoints)


func update_waypoint_progress(index: int):
	current_waypoint_index = index
	progress_changed.emit(current_waypoint_index, total_waypoints)


func complete_level():
	SaveManager.mark_level_completed(current_level)
	level_completed.emit(current_level)


func check_web_launch_chapter() -> int:
	if not OS.has_feature("web"):
		return -1

	var js_eval = """
	(function() {
		try {
			var params = new URLSearchParams(window.location.search);
			var chap = params.get('chapter') || params.get('level') || params.get('scene');
			if (chap && !isNaN(parseInt(chap))) {
				return parseInt(chap);
			}
		} catch(e) {}
		return -1;
	})()
	"""

	var result = JavaScriptBridge.eval(js_eval)
	if result != null:
		var parsed_id := -1
		if typeof(result) == TYPE_INT:
			parsed_id = result
		elif typeof(result) == TYPE_FLOAT:
			parsed_id = int(result)

		if parsed_id > 0 and level_scenes.has(parsed_id):
			current_level = parsed_id
			return parsed_id

	return -1
