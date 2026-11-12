extends Node

signal progress_changed(current_index, total_count)
signal level_completed(level_id)

var current_level := 1

var level_scenes := {
	1: "res://Scenes/scene_1.tscn",
	2: "res://Scenes/scene_2.tscn",
	3: "res://Scenes/scene_3.tscn",
	4: "res://Scenes/scene_4.tscn"
}


func resolve_level_scene(level_id: int) -> String:
	var direct_path := "res://Scenes/scene_%d.tscn" % level_id
	if ResourceLoader.exists(direct_path):
		level_scenes[level_id] = direct_path
		return direct_path

	if level_scenes.has(level_id) and ResourceLoader.exists(String(level_scenes[level_id])):
		return String(level_scenes[level_id])

	for idx in range(20, 0, -1):
		var candidate_path := "res://Scenes/scene_%d.tscn" % idx
		if ResourceLoader.exists(candidate_path):
			level_scenes[level_id] = candidate_path
			return candidate_path

	return String(level_scenes.get(1, "res://Scenes/scene_1.tscn"))


func get_current_level_scene() -> String:
	return resolve_level_scene(current_level)


var current_waypoint_index := 0
var total_waypoints := 0

var use_dialogue_progression := false
var current_answers_count := 0
var total_answers_count := 0
var dialogue_totals := {}
var dialogue_answered_counts := {}
var answered_questions := {}


func setup_level(level_id: int, context = null):
	current_level = level_id
	current_waypoint_index = 0
	GameManager.chapter_is_finished = false
	DialogueManager.end()
	GameManager.cancel_word()
	GameManager.completed_tasks = []

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
		var bgm = scene_node.get_node_or_null("AudioStreamPlayer")
		if bgm != null and bgm is AudioStreamPlayer and not bgm.playing:
			bgm.play()

		if scene_node.has_node("Waypoints"):
			total_waypoints = scene_node.get_node("Waypoints").get_child_count()

		var npcs = _find_all_npcs(scene_node)
		for npc in npcs:
			var d_file = npc.get("dialogue_file")
			if d_file != null:
				var path_str := _normalize_dialogue_path(String(d_file))
				if not path_str.is_empty() and not dialogue_totals.has(path_str):
					var count = get_canonical_answer_count(path_str)
					if count > 0:
						dialogue_totals[path_str] = count
						dialogue_answered_counts[path_str] = 0
						total_answers_count += count

	var saved_level = int(SaveManager.save_data.get("current_level", -1))
	var has_level_progress = (
		float(SaveManager.save_data.get("progress_percent", 0)) > 0.0 or
		int(SaveManager.save_data.get("current_progress_value", 0)) > 0 or
		int(SaveManager.save_data.get("answer_progress", 0)) > 0 or
		int(SaveManager.save_data.get("waypoint_index", 0)) > 0
	)
	var is_valid_level = (saved_level == level_id or (saved_level <= 1 and has_level_progress))
	if not SaveManager.restart_pending and is_valid_level:
		SaveManager.save_data["current_level"] = level_id
		var progress_ratio := 0.0
		var raw_pct = float(SaveManager.save_data.get("progress_percent", 0))
		if raw_pct > 0.0:
			progress_ratio = raw_pct / 100.0
		elif int(SaveManager.save_data.get("current_progress_total", 0)) > 0:
			progress_ratio = float(SaveManager.save_data.get("current_progress_value", 0)) / float(SaveManager.save_data.get("current_progress_total", 1))
		elif int(SaveManager.save_data.get("total_answers", 0)) > 0:
			progress_ratio = float(SaveManager.save_data.get("answer_progress", 0)) / float(SaveManager.save_data.get("total_answers", 1))

		var saved_wp = int(SaveManager.save_data.get("waypoint_index", 0))
		if saved_wp > 0 and saved_wp <= total_waypoints:
			current_waypoint_index = saved_wp
		elif progress_ratio > 0.0 and total_waypoints > 0:
			current_waypoint_index = clampi(int(round(progress_ratio * float(total_waypoints))), 0, total_waypoints)
			SaveManager.save_data["waypoint_index"] = current_waypoint_index

		var saved_ans = int(SaveManager.save_data.get("answer_progress", 0))
		if saved_ans > 0:
			current_answers_count = min(saved_ans, total_answers_count)

		var saved_questions = SaveManager.save_data.get("answered_questions", [])
		if typeof(saved_questions) == TYPE_ARRAY:
			for q_key in saved_questions:
				answered_questions[String(q_key)] = true
				for path in dialogue_totals:
					if String(q_key).begins_with(String(path) + "::"):
						dialogue_answered_counts[path] = min(int(dialogue_answered_counts[path]) + 1, int(dialogue_totals[path]))

		var raw_tasks = SaveManager.save_data.get("completed_tasks", [])
		if typeof(raw_tasks) == TYPE_ARRAY:
			GameManager.completed_tasks = raw_tasks.duplicate()

		var waypoints_node = scene_node.get_node_or_null("Waypoints") if scene_node != null else null
		var waypoints_list: Array = waypoints_node.get_children() if waypoints_node != null else []
		var active_checkpoint_source := ""
		var checkpoint = SaveManager.save_data.get("dialogue_checkpoint", {})
		if checkpoint is Dictionary and checkpoint.has("source"):
			active_checkpoint_source = _normalize_dialogue_path(String(checkpoint.get("source", "")))

		if scene_node != null and (current_waypoint_index > 0 or progress_ratio > 0.0):
			var all_npcs = _find_all_npcs(scene_node)
			for npc in all_npcs:
				var d_file = npc.get("dialogue_file")
				if d_file == null:
					continue
				var path_str: String = _normalize_dialogue_path(String(d_file))
				if path_str.is_empty() or path_str == active_checkpoint_source:
					continue

				var should_complete := false
				var can_steps: int = int(dialogue_totals.get(path_str, 0))

				if can_steps == 0 and progress_ratio > 0.0:
					should_complete = true
				elif not waypoints_list.is_empty() and npc is Node2D:
					var best_wp_idx := -1
					var best_dist := 9999999.0
					for i in range(waypoints_list.size()):
						var wp_node = waypoints_list[i]
						if wp_node is Node2D:
							var d = npc.global_position.distance_to(wp_node.global_position)
							if d < best_dist:
								best_dist = d
								best_wp_idx = i + 1
					if best_wp_idx > 0 and current_waypoint_index >= best_wp_idx:
						should_complete = true

				if should_complete:
					var done_key: String = "DIALOGUE_DONE::" + path_str
					if not GameManager.completed_tasks.has(done_key):
						GameManager.completed_tasks.append(done_key)
					if dialogue_totals.has(path_str):
						dialogue_answered_counts[path_str] = int(dialogue_totals[path_str])

	if total_answers_count > 0:
		use_dialogue_progression = true
		print("[LevelManager] Level %d initialized with dialogue+waypoint progression: %d/%d answers, %d/%d waypoints." % [current_level, current_answers_count, total_answers_count, current_waypoint_index, total_waypoints])
	else:
		use_dialogue_progression = false
		print("[LevelManager] Level %d initialized with waypoint progression: %d/%d waypoints." % [current_level, current_waypoint_index, total_waypoints])

	progress_changed.emit(get_current_progress_value(), get_current_progress_total())


func _find_all_npcs(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	if node == null:
		return result

	if node.get("dialogue_file") != null and not String(node.get("dialogue_file")).is_empty():
		result.append(node)

	for child in node.get_children():
		result.append_array(_find_all_npcs(child))

	return result


func _normalize_dialogue_path(dialogue_path: String) -> String:
	var path = String(dialogue_path).strip_edges()
	if path.begins_with("uid://"):
		var uid_id = ResourceUID.text_to_id(path)
		if uid_id != ResourceUID.INVALID_ID and ResourceUID.has_id(uid_id):
			return ResourceUID.get_id_path(uid_id)
	return path


func get_canonical_answer_count(dialogue_path: String) -> int:
	var resolved_path = _normalize_dialogue_path(dialogue_path)
	if resolved_path.is_empty():
		return 0

	var file = FileAccess.open(resolved_path, FileAccess.READ)
	if file == null:
		push_warning("LevelManager could not open dialogue file: %s" % resolved_path)
		return 0

	var text = file.get_as_text()
	var json = JSON.new()
	if json.parse(text) != OK:
		push_warning("LevelManager failed to parse JSON in %s" % resolved_path)
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
	var resolved_path = _normalize_dialogue_path(dialogue_path)
	if not use_dialogue_progression or resolved_path.is_empty():
		return

	var question_key := "%s::%d" % [resolved_path, node_id]
	if answered_questions.has(question_key):
		return

	answered_questions[question_key] = true

	var max_for_dialogue: int = dialogue_totals.get(resolved_path, 0)
	var credited_for_dialogue: int = dialogue_answered_counts.get(resolved_path, 0)

	if credited_for_dialogue < max_for_dialogue:
		dialogue_answered_counts[resolved_path] = credited_for_dialogue + 1
		current_answers_count = min(current_answers_count + 1, total_answers_count)
		progress_changed.emit(get_current_progress_value(), get_current_progress_total())
		SaveManager.save_game()


func register_dialogue_finished(dialogue_path: String):
	var resolved_path: String = _normalize_dialogue_path(dialogue_path)
	if resolved_path.is_empty():
		return
	var max_for_dialogue: int = int(dialogue_totals.get(resolved_path, 0))
	var credited_for_dialogue: int = int(dialogue_answered_counts.get(resolved_path, 0))
	if max_for_dialogue > 0 and credited_for_dialogue < max_for_dialogue:
		return
	var done_key: String = "DIALOGUE_DONE::" + resolved_path
	if not GameManager.completed_tasks.has(done_key):
		GameManager.completed_tasks.append(done_key)


func is_dialogue_completed(dialogue_path: String) -> bool:
	var resolved_path: String = _normalize_dialogue_path(dialogue_path)
	if resolved_path.is_empty():
		return false
	if GameManager.completed_tasks.has("DIALOGUE_DONE::" + resolved_path):
		return true
	var max_for_dialogue: int = int(dialogue_totals.get(resolved_path, 0))
	var credited_for_dialogue: int = int(dialogue_answered_counts.get(resolved_path, 0))
	if max_for_dialogue > 0 and credited_for_dialogue >= max_for_dialogue:
		return true
	return false


func get_current_progress_value() -> int:
	if use_dialogue_progression:
		return clampi(current_answers_count + current_waypoint_index, 0, get_current_progress_total())
	return clampi(current_waypoint_index, 0, get_current_progress_total())


func get_current_progress_total() -> int:
	if use_dialogue_progression:
		return maxi(1, total_answers_count + total_waypoints)
	return maxi(1, total_waypoints)


func update_waypoint_progress(index: int):
	current_waypoint_index = clampi(index, 0, maxi(total_waypoints, index))
	progress_changed.emit(get_current_progress_value(), get_current_progress_total())


func complete_level():
	current_waypoint_index = total_waypoints
	current_answers_count = total_answers_count
	progress_changed.emit(get_current_progress_value(), get_current_progress_total())
	SaveManager.mark_level_completed(current_level)
	level_completed.emit(current_level)


func check_web_launch_chapter() -> int:
	if not OS.has_feature("web"):
		return -1

	var js_eval = "\n\t(function() {\n\t\ttry {\n\t\t\tvar params = new URLSearchParams(window.location.search);\n\t\t\tvar chap = params.get('chapter') || params.get('level') || params.get('scene');\n\t\t\tif (chap && !isNaN(parseInt(chap))) {\n\t\t\t\treturn parseInt(chap);\n\t\t\t}\n\t\t} catch(e) {}\n\t\treturn -1;\n\t})()\n\t"

	var result = JavaScriptBridge.eval(js_eval)
	if result != null:
		var parsed_id := -1
		if typeof(result) == TYPE_INT:
			parsed_id = result
		elif typeof(result) == TYPE_FLOAT:
			parsed_id = int(result)

		if parsed_id > 0:
			level_scenes[parsed_id] = resolve_level_scene(parsed_id)
			current_level = parsed_id
			return parsed_id

	return -1
