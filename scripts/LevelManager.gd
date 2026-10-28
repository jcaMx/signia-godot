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

# Dialogue-based progress state
var use_dialogue_progression := false
var current_answers_count := 0
var total_answers_count := 0
var dialogue_totals := {}          # String (dialogue_path) -> int (canonical answer count)
var dialogue_answered_counts := {} # String (dialogue_path) -> int (answers credited)
var answered_questions := {}       # String ("dialogue_path::node_id") -> bool


func setup_level(level_id: int, context = null):
	current_level = level_id
	current_waypoint_index = 0
	GameManager.chapter_is_finished = false
	DialogueManager.end()
	GameManager.cancel_word()

	# Reset dialogue progress tracking
	current_answers_count = 0
	total_answers_count = 0
	dialogue_totals.clear()
	dialogue_answered_counts.clear()
	answered_questions.clear()
	use_dialogue_progression = false

	var scene_node: Node = null
	if context is Node:
		scene_node = context
	elif context is int:
		total_waypoints = context

	if scene_node == null and get_tree() != null:
		scene_node = get_tree().current_scene

	if scene_node != null:
		if scene_node.has_node("Waypoints"):
			total_waypoints = scene_node.get_node("Waypoints").get_child_count()

		var npcs = _find_all_npcs(scene_node)
		for npc in npcs:
			var d_file = npc.get("dialogue_file")
			if d_file != null:
				var path_str := String(d_file)
				if not path_str.is_empty() and not dialogue_totals.has(path_str):
					var count = get_canonical_answer_count(path_str)
					if count > 0:
						dialogue_totals[path_str] = count
						dialogue_answered_counts[path_str] = 0
						total_answers_count += count

	# Restore saved progress if this level matches the save data
	if SaveManager.save_data.get("current_level") == level_id:
		var saved_wp = int(SaveManager.save_data.get("waypoint_index", 0))
		if saved_wp > 0 and saved_wp <= total_waypoints:
			current_waypoint_index = saved_wp

		var saved_ans = int(SaveManager.save_data.get("answer_progress", 0))
		if saved_ans > 0:
			current_answers_count = min(saved_ans, total_answers_count)

		var saved_questions = SaveManager.save_data.get("answered_questions", [])
		if typeof(saved_questions) == TYPE_ARRAY:
			for q_key in saved_questions:
				answered_questions[String(q_key)] = true

	if total_answers_count > 0:
		use_dialogue_progression = true
		print("[LevelManager] Level %d initialized with dialogue progression: %d/%d answers required across %d dialogues." % [current_level, current_answers_count, total_answers_count, dialogue_totals.size()])
		progress_changed.emit(current_answers_count, total_answers_count)
	else:
		use_dialogue_progression = false
		print("[LevelManager] Level %d initialized with waypoint progression: %d/%d waypoints." % [current_level, current_waypoint_index, total_waypoints])
		progress_changed.emit(current_waypoint_index, total_waypoints)


func _find_all_npcs(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	if node == null:
		return result

	if node.get("dialogue_file") != null and not String(node.get("dialogue_file")).is_empty():
		result.append(node)

	for child in node.get_children():
		result.append_array(_find_all_npcs(child))

	return result


func get_canonical_answer_count(dialogue_path: String) -> int:
	if dialogue_path.is_empty():
		return 0

	var file = FileAccess.open(dialogue_path, FileAccess.READ)
	if file == null:
		push_warning("LevelManager could not open dialogue file: %s" % dialogue_path)
		return 0

	var text = file.get_as_text()
	var json = JSON.new()
	if json.parse(text) != OK:
		push_warning("LevelManager failed to parse JSON in %s" % dialogue_path)
		return 0

	var data = json.data
	if typeof(data) != TYPE_ARRAY or data.is_empty():
		return 0

	var nodes_by_id := {}
	for item in data:
		if typeof(item) == TYPE_DICTIONARY and item.has("id"):
			nodes_by_id[int(item["id"])] = item

	if nodes_by_id.is_empty():
		return 0

	var curr_id := 0
	if not nodes_by_id.has(curr_id):
		curr_id = int(data[0].get("id", -1))

	var canonical_steps := 0
	var visited := {}

	while curr_id != -1 and nodes_by_id.has(curr_id) and not visited.has(curr_id):
		visited[curr_id] = true
		var node: Dictionary = nodes_by_id[curr_id]
		var choices = node.get("choices", [])
		if typeof(choices) == TYPE_ARRAY and not choices.is_empty():
			canonical_steps += 1
			var first_choice = choices[0]
			if typeof(first_choice) == TYPE_DICTIONARY:
				curr_id = int(first_choice.get("next", -1))
			else:
				curr_id = -1
		else:
			curr_id = int(node.get("next", -1))

	return canonical_steps


func register_dialogue_answer(dialogue_path: String, node_id: int):
	if not use_dialogue_progression or dialogue_path.is_empty():
		return

	var question_key := "%s::%d" % [dialogue_path, node_id]
	if answered_questions.has(question_key):
		# Prevent double-counting on loops/retries
		return

	answered_questions[question_key] = true

	var max_for_dialogue: int = dialogue_totals.get(dialogue_path, 0)
	var credited_for_dialogue: int = dialogue_answered_counts.get(dialogue_path, 0)

	if credited_for_dialogue < max_for_dialogue:
		dialogue_answered_counts[dialogue_path] = credited_for_dialogue + 1
		current_answers_count = min(current_answers_count + 1, total_answers_count)
		progress_changed.emit(current_answers_count, total_answers_count)
		SaveManager.save_game()


func register_dialogue_finished(_dialogue_path: String):
	# Progress is driven strictly per player answer (not auto-filled on dialogue close)
	pass


func get_current_progress_value() -> int:
	if use_dialogue_progression:
		return current_answers_count
	return current_waypoint_index


func get_current_progress_total() -> int:
	if use_dialogue_progression:
		return total_answers_count
	return total_waypoints


func update_waypoint_progress(index: int):
	current_waypoint_index = index
	if not use_dialogue_progression:
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
