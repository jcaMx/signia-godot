extends Node

const SAVE_PATH := "user://save_data.json"
const WEB_STORAGE_KEY := "signia_save_data"

var save_data := {
	"current_level": 1,
	"unlocked_level": 1,
	"waypoint_index": 0,
	"completed_levels": [],
	"completed_tasks": [],
	"volume": 1.0
}


func save_game():
	save_data["current_level"] = LevelManager.current_level
	save_data["waypoint_index"] = LevelManager.current_waypoint_index
	save_data["completed_tasks"] = GameManager.completed_tasks

	# 1. Save to local user file (IndexedDB in Web export)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(save_data))

	# 2. Web bridge: Sync with host website via localStorage & window.postMessage
	_sync_to_web()


func load_game() -> bool:
	var loaded := false

	# First try loading from local user file
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				save_data = parsed
				loaded = true

	# Web fallback: If local file didn't exist or on Web, try loading from browser localStorage
	if not loaded and OS.has_feature("web"):
		var web_data = _load_from_web()
		if not web_data.is_empty():
			save_data = web_data
			loaded = true

	if save_data.has("volume"):
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(save_data["volume"]))

	return loaded


func mark_level_completed(level_id: int):
	if not save_data["completed_levels"].has(level_id):
		save_data["completed_levels"].append(level_id)

	save_data["unlocked_level"] = max(save_data["unlocked_level"], level_id + 1)
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

	# Save to localStorage
	if window.localStorage:
		window.localStorage.setItem(WEB_STORAGE_KEY, json_str)

	# Send progress event to parent website iframe (window.parent.postMessage)
	var payload_eval = """
	(function(payloadStr) {
		try {
			var payload = JSON.parse(payloadStr);
			payload.type = 'SIGNIA_PROGRESS_UPDATE';
			// Post message to parent website window if embedded in an iframe
			if (window.parent && window.parent !== window) {
				window.parent.postMessage(payload, '*');
			}
			// Also dispatch custom DOM event on current window
			window.dispatchEvent(new CustomEvent('signia_progress_update', { detail: payload }));
		} catch(e) {
			console.error('Signia Web Sync Error:', e);
		}
	})('%s');
	""" % json_str.replace("'", "\\'")

	JavaScriptBridge.eval(payload_eval)


func _load_from_web() -> Dictionary:
	if not OS.has_feature("web"):
		return {}

	var js_eval = """
	(function() {
		try {
			if (window.SIGNIA_INITIAL_SAVE) {
				return typeof window.SIGNIA_INITIAL_SAVE === 'string' 
					? window.SIGNIA_INITIAL_SAVE 
					: JSON.stringify(window.SIGNIA_INITIAL_SAVE);
			}
			if (window.localStorage) {
				return window.localStorage.getItem('%s') || '';
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
