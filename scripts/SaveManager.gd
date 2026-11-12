extends Node

const SAVE_PATH := "user://save_data.json"
const WEB_STORAGE_KEY := "signia_save_data"
var restoring := false
var restart_pending := false
var has_loaded_initial := false
var player_ref: Node2D = null

var save_data := {
	"current_level": 1,
	"unlocked_level": 1,
	"waypoint_index": 0,
	"answer_progress": 0,
	"total_answers": 0,
	"completed_levels": [],
	"completed_tasks": [],
	"answered_questions": [],
	"player_checkpoint": {},
	"dialogue_checkpoint": {},
	"volume": 1.0,
	"is_restart": false
}


func save_game(is_restart_save: bool = false):
	if restoring:
		return
	save_data["current_level"] = LevelManager.current_level
	save_data["waypoint_index"] = LevelManager.current_waypoint_index
	save_data["answer_progress"] = LevelManager.current_answers_count
	save_data["total_answers"] = LevelManager.total_answers_count
	save_data["completed_tasks"] = GameManager.completed_tasks.duplicate()
	save_data["answered_questions"] = LevelManager.answered_questions.keys()
	save_data["is_restart"] = is_restart_save
	if is_restart_save:
		save_data["player_checkpoint"] = {}
		save_data["dialogue_checkpoint"] = {}
	else:
		if is_instance_valid(player_ref):
			save_data["player_checkpoint"] = {
				"x": player_ref.global_position.x,
				"y": player_ref.global_position.y,
				"waypoint_index": int(player_ref.current_index),
				"waiting": false,
			}
		var speaker = DialogueManager.get_active_speaker_node()
		var scene = get_tree().current_scene
		save_data["dialogue_checkpoint"] = {}
		if DialogueManager.active and scene != null and is_instance_valid(speaker) and scene.is_ancestor_of(speaker):
			save_data["dialogue_checkpoint"] = {
				"speaker": str(scene.get_path_to(speaker)),
				"source": DialogueManager.current_source,
				"node": DialogueManager.current_id,
			}

	var total = LevelManager.get_current_progress_total()
	var current = 0 if is_restart_save else LevelManager.get_current_progress_value()
	var pct = 0
	if total > 0 and not is_restart_save:
		pct = int(round(float(current) / float(total) * 100.0))
	save_data["progress_percent"] = pct
	save_data["current_progress_value"] = current
	save_data["current_progress_total"] = total

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(save_data))

	_sync_to_web()


func apply_save_data(new_data: Dictionary):
	if new_data.is_empty():
		return
	if new_data.has("data") and typeof(new_data["data"]) == TYPE_DICTIONARY:
		for inner_key in new_data["data"]:
			save_data[inner_key] = new_data["data"][inner_key]
	for key in new_data:
		if key != "data" and key != "type":
			save_data[key] = new_data[key]


func prepare_chapter_restart():
	restoring = true
	restart_pending = true
	LevelManager.current_waypoint_index = 0
	LevelManager.current_answers_count = 0
	LevelManager.dialogue_answered_counts.clear()
	LevelManager.answered_questions.clear()
	GameManager.completed_tasks = []
	GameManager.cancel_word()
	save_data = {
		"current_level": LevelManager.current_level,
		"unlocked_level": save_data.get("unlocked_level", 1),
		"completed_levels": save_data.get("completed_levels", []),
		"volume": save_data.get("volume", 1.0),
		"waypoint_index": 0,
		"answer_progress": 0,
		"total_answers": LevelManager.total_answers_count,
		"current_progress_value": 0,
		"current_progress_total": LevelManager.get_current_progress_total(),
		"progress_percent": 0,
		"completed_tasks": [],
		"answered_questions": [],
		"player_checkpoint": {},
		"dialogue_checkpoint": {},
		"is_restart": true,
	}
	DialogueManager.require_player_continue_after_end = false
	LevelManager.progress_changed.emit(0, LevelManager.get_current_progress_total())
	_clear_web_initial_save()


func load_game() -> bool:
	restoring = true
	player_ref = null
	if restart_pending:
		return true
	has_loaded_initial = true
	var loaded := false

	if OS.has_feature("web") and _has_website_save():
		save_data = {
			"current_level": 1,
			"unlocked_level": 1,
			"waypoint_index": 0,
			"answer_progress": 0,
			"total_answers": 0,
			"completed_levels": [],
			"completed_tasks": [],
			"answered_questions": [],
			"player_checkpoint": {},
			"dialogue_checkpoint": {},
			"volume": 1.0,
			"is_restart": false,
		}
		var web_save = _load_from_web()
		apply_save_data(web_save)
		return not web_save.is_empty()

	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				apply_save_data(parsed)
				loaded = true

	if not loaded and OS.has_feature("web"):
		var web_data = _load_from_web()
		if not web_data.is_empty():
			apply_save_data(web_data)
			loaded = true

	if save_data.has("volume"):
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(float(save_data["volume"])))

	return loaded


func _has_website_save() -> bool:
	return JavaScriptBridge.eval("""
	(function() {
		try {
			var params = new URLSearchParams(window.location.search);
			if (params.get('restart') === '1' || params.get('forceFresh') === '1') return true;
			if (params.get('save')) return true;
			if (window.SIGNIA_INITIAL_SAVE && typeof window.SIGNIA_INITIAL_SAVE === 'object') return true;
			if (window.parent && window.parent !== window && window.parent.SIGNIA_INITIAL_SAVE && typeof window.parent.SIGNIA_INITIAL_SAVE === 'object') return true;
			if (window.localStorage && window.localStorage.getItem('signia_save_data')) return true;
			if (params.get('pct') || params.get('step')) return true;
		} catch (e) {}
		return false;
	})()
	""") == true


func _clear_web_initial_save():
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
	(function() {
		try {
			window.SIGNIA_INITIAL_SAVE = null;
			if (window.parent && window.parent !== window) {
				window.parent.SIGNIA_INITIAL_SAVE = null;
			}
			if (window.localStorage) {
				window.localStorage.removeItem('signia_save_data');
			}
		} catch (e) {}
	})()
	""")


func apply_player_position(player: Node2D):
	player_ref = player
	if restart_pending:
		return
	var saved_level = int(save_data.get("current_level", -1))
	if saved_level <= 0 or saved_level == 1:
		save_data["current_level"] = player.level_id
	if int(save_data.get("current_level", -1)) != player.level_id:
		return

	var position_data = save_data.get("player_checkpoint", {})
	if position_data is Dictionary and position_data.has("x") and position_data.has("y"):
		var x = float(position_data.x)
		var y = float(position_data.y)
		if is_finite(x) and is_finite(y):
			var saved_waypoint = int(position_data.get("waypoint_index", save_data.get("waypoint_index", 0)))
			player.current_index = clampi(saved_waypoint, 0, player.waypoints.size())
			player.global_position = Vector2(x, y)
			player.waiting_for_continue_input = false
			return

	var saved_waypoint = int(save_data.get("waypoint_index", 0))
	if saved_waypoint > 0 and not player.waypoints.is_empty():
		player.current_index = clampi(saved_waypoint, 0, player.waypoints.size())
		var wp_idx = clampi(saved_waypoint - 1, 0, player.waypoints.size() - 1)
		player.global_position = player.waypoints[wp_idx].global_position
		player.waiting_for_continue_input = false
		return

	var pct = float(save_data.get("progress_percent", 0)) / 100.0
	if pct <= 0.0 and int(save_data.get("current_progress_total", 0)) > 0:
		pct = float(save_data.get("current_progress_value", 0)) / float(save_data.get("current_progress_total", 1))
	if pct <= 0.0 and int(save_data.get("total_answers", 0)) > 0:
		pct = float(save_data.get("answer_progress", 0)) / float(save_data.get("total_answers", 1))

	if pct > 0.0 and not player.waypoints.is_empty():
		var est_wp = clampi(int(round(pct * float(player.waypoints.size()))), 1, player.waypoints.size())
		player.current_index = est_wp
		LevelManager.current_waypoint_index = est_wp
		var wp_idx = clampi(est_wp - 1, 0, player.waypoints.size() - 1)
		player.global_position = player.waypoints[wp_idx].global_position
		player.waiting_for_continue_input = false


func restore_player(player: Node2D):
	player_ref = player
	var was_restart := restart_pending
	var saved_level = int(save_data.get("current_level", -1))
	if saved_level <= 0 or saved_level == 1:
		save_data["current_level"] = player.level_id

	if not was_restart and int(save_data.get("current_level", -1)) == player.level_id:
		apply_player_position(player)
		var checkpoint = save_data.get("dialogue_checkpoint", {})
		var scene = get_tree().current_scene
		if checkpoint is Dictionary and scene != null and not checkpoint.is_empty():
			var speaker = scene.get_node_or_null(NodePath(str(checkpoint.get("speaker", ""))))
			var speaker_dialogue = DialogueManager._normalize_dialogue_path(str(speaker.get("dialogue_file"))) if is_instance_valid(speaker) else ""
			var checkpoint_source = DialogueManager._normalize_dialogue_path(str(checkpoint.get("source", "")))
			if is_instance_valid(speaker) and scene.is_ancestor_of(speaker) and speaker_dialogue == checkpoint_source:
				DialogueManager.start(
					str(speaker.dialogue_file),
					speaker,
					false,
					int(checkpoint.get("node", -1))
				)
	restoring = false
	if was_restart:
		restart_pending = false
		LevelManager.current_waypoint_index = 0
		LevelManager.current_answers_count = 0
		LevelManager.progress_changed.emit(0, LevelManager.get_current_progress_total())
		save_game(true)
	else:
		LevelManager.progress_changed.emit(LevelManager.get_current_progress_value(), LevelManager.get_current_progress_total())
		save_game(false)


func mark_level_completed(level_id: int):
	if not save_data["completed_levels"].has(level_id):
		save_data["completed_levels"].append(level_id)

	save_data["unlocked_level"] = max(int(save_data.get("unlocked_level", 1)), level_id + 1)
	save_game()
	_notify_chapter_finished(level_id)


func _notify_chapter_finished(level_id: int):
	if not OS.has_feature("web"):
		return

	var js_eval = """
	(function(levelId) {
		try {
			var payload = {
				type: 'SIGNIA_CHAPTER_FINISHED',
				level_id: levelId
			};
			if (window.parent && window.parent !== window) {
				window.parent.postMessage(payload, '*');
			}
			window.dispatchEvent(new CustomEvent('signia_chapter_finished', { detail: payload }));
		} catch(e) {}
	})(%d);
	""" % level_id

	JavaScriptBridge.eval(js_eval)


func _sync_to_web():
	if not OS.has_feature("web"):
		return

	var window = JavaScriptBridge.get_interface("window")
	if window == null:
		return

	var json_str = JSON.stringify(save_data)

	if window.localStorage:
		if save_data.get("is_restart", false) == true:
			window.localStorage.removeItem(WEB_STORAGE_KEY)
		else:
			window.localStorage.setItem(WEB_STORAGE_KEY, json_str)

	var payload_eval = """
	(function(payloadStr) {
		try {
			var payload = JSON.parse(payloadStr);
			payload.type = 'SIGNIA_PROGRESS_UPDATE';
			window.SIGNIA_INITIAL_SAVE = payload.is_restart ? null : payload;
			// Post message to parent website window if embedded in an iframe
			if (window.parent && window.parent !== window) {
				try {
					window.parent.SIGNIA_INITIAL_SAVE = payload.is_restart ? null : payload;
				} catch (err) {}
				window.parent.postMessage(payload, '*');
			}
			// Also dispatch custom DOM event on current window
			window.dispatchEvent(new CustomEvent('signia_progress_update', { detail: payload }));
		} catch(e) {
			console.error('Signia Web Sync Error:', e);
		}
	})('%s');
	""" % json_str.replace("\\", "\\\\").replace("'", "\\'")

	JavaScriptBridge.eval(payload_eval)


func _load_from_web() -> Dictionary:
	if not OS.has_feature("web"):
		return {}

	var js_eval = """
	(function() {
		try {
			var hasUrl = Boolean(window.location && window.location.search);
			var params = hasUrl ? new URLSearchParams(window.location.search) : null;
			var chap = 1;
			if (params) {
				var parsedChap = parseInt(params.get('chapter') || params.get('level') || '1');
				if (!isNaN(parsedChap) && parsedChap > 0) chap = parsedChap;
			}

			if (params && (params.get('restart') === '1' || params.get('forceFresh') === '1')) {
				return JSON.stringify({ is_restart: true, current_level: chap, progress_percent: 0, waypoint_index: 0 });
			}

			function parseSaveObj(val) {
				if (!val) return null;
				if (typeof val === 'string') {
					try { val = JSON.parse(val); } catch(e) { return null; }
				}
				if (typeof val !== 'object' || Array.isArray(val) || val.is_restart) return null;
				return Object.keys(val).length > 0 ? val : null;
			}

			// The launch URL carries the complete backend checkpoint so game startup
			// does not depend on iframe/global timing for dialogue and position state.
			var candidate = params ? parseSaveObj(params.get('save')) : null;
			if (!candidate) candidate = parseSaveObj(window.SIGNIA_INITIAL_SAVE);
			if (!candidate && window.parent && window.parent !== window) {
				candidate = parseSaveObj(window.parent.SIGNIA_INITIAL_SAVE);
			}

			var pct = params ? parseInt(params.get('pct') || '0') : 0;
			var step = params ? parseInt(params.get('step') || '0') : 0;
			var total = params ? parseInt(params.get('total') || '0') : 0;
			var wp = params ? parseInt(params.get('wp') || '0') : 0;
			var hasUrlProgress = (pct > 0 || step > 0 || wp > 0);

			if (candidate) {
				if (!candidate.current_level || candidate.current_level <= 0) candidate.current_level = chap;
				if (hasUrlProgress) {
					if (!candidate.progress_percent || candidate.progress_percent <= 0) candidate.progress_percent = pct;
					if (!candidate.current_progress_value || candidate.current_progress_value <= 0) candidate.current_progress_value = step;
					if (!candidate.current_progress_total || candidate.current_progress_total <= 0) candidate.current_progress_total = total;
					if (!candidate.waypoint_index || candidate.waypoint_index <= 0) candidate.waypoint_index = wp > 0 ? wp : step;
				}
				return JSON.stringify(candidate);
			}

			if (window.parent && window.parent !== window &&
				Object.prototype.hasOwnProperty.call(window.parent, 'SIGNIA_INITIAL_SAVE') &&
				window.parent.SIGNIA_INITIAL_SAVE === null && !hasUrlProgress) {
				return '{}';
			}

			if (hasUrlProgress) {
				// `step` may be combined dialogue + waypoint progress. Only an
				// explicit waypoint index can safely set the player's path position.
				var autoWp = wp > 0 ? wp : 0;
				return JSON.stringify({
					current_level: chap,
					progress_percent: pct,
					current_progress_value: step,
					current_progress_total: total,
					waypoint_index: autoWp,
					completed_tasks: [],
					answered_questions: [],
					is_restart: false
				});
			}

			if (window.localStorage) {
				var local = window.localStorage.getItem('signia_save_data_ch' + chap) || window.localStorage.getItem('%s');
				var parsedLocal = parseSaveObj(local);
				if (parsedLocal) {
					if (!parsedLocal.current_level || parsedLocal.current_level <= 0) parsedLocal.current_level = chap;
					return JSON.stringify(parsedLocal);
				}
			}
		} catch(e) {}
		return '';
	})()
	""" % WEB_STORAGE_KEY

	var raw_res = JavaScriptBridge.eval(js_eval)
	if raw_res != null and typeof(raw_res) == TYPE_STRING and not String(raw_res).is_empty():
		var parsed = JSON.parse_string(raw_res)
		if typeof(parsed) == TYPE_DICTIONARY:
			return parsed

	return {}
