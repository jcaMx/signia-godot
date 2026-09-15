extends Node

signal dialogue_started
signal dialogue_updated(speaker, text, choices)
signal dialogue_ended

const NODE_TYPE_NPC := "npc"
const NODE_TYPE_NARRATOR := "narrator"

var active := false
var current_id := -1
var current_source := ""
var dialogue_nodes: Dictionary = {}
var dialogue_order: Array = []
var last_node_change_frame := -1
var active_speaker_node: Node = null
var require_player_continue_after_end := false
var pending_player_continue := false


func start(dialogue_source, speaker_node: Node = null, require_continue_after_end: bool = false):
	var nodes = _resolve_dialogue_source(dialogue_source)
	if nodes.is_empty():
		push_warning("DialogueManager.start received an empty dialogue source.")
		return

	var node_map = _build_node_map(nodes)
	if node_map.is_empty():
		push_error("DialogueManager could not build a valid dialogue graph.")
		return

	dialogue_nodes = node_map
	dialogue_order = nodes
	current_source = dialogue_source if dialogue_source is String else ""
	current_id = _resolve_start_id(nodes, node_map)
	active_speaker_node = speaker_node
	require_player_continue_after_end = require_continue_after_end
	pending_player_continue = false
	active = true

	dialogue_started.emit()
	_emit_current_node()


func choose(choice_index: int):
	if not active:
		return

	var node = get_current_node()
	if node.is_empty():
		end()
		return

	if not is_current_node_npc():
		return

	var choices = _sanitize_choices(node.get("choices", []))
	if choice_index < 0 or choice_index >= choices.size():
		return

	_advance_to(choices[choice_index].get("next", -1))


func advance():
	if not active:
		return

	var node = get_current_node()
	if node.is_empty():
		end()
		return

	if is_current_node_narrator():
		_advance_to(node.get("next", -1))
		return

	if not _sanitize_choices(node.get("choices", [])).is_empty():
		return

	_advance_to(node.get("next", -1))


func process_sign(sign_id: String):
	if not active:
		return

	var node = get_current_node()
	if node.is_empty():
		end()
		return

	if not is_current_node_npc():
		return

	for choice in _sanitize_choices(node.get("choices", [])):
		if SignProcessor.are_signs_matching(sign_id, String(choice.get("sign", ""))):
			_advance_to(choice.get("next", -1))
			return


func get_current_node() -> Dictionary:
	if not dialogue_nodes.has(current_id):
		return {}

	var node = dialogue_nodes[current_id]
	if typeof(node) != TYPE_DICTIONARY:
		return {}

	return node


func get_current_node_type() -> String:
	return _resolve_node_type(get_current_node())


func get_current_display_mode() -> String:
	return get_current_node_type()


func is_current_node_npc() -> bool:
	return get_current_node_type() == NODE_TYPE_NPC


func is_current_node_narrator() -> bool:
	return get_current_node_type() == NODE_TYPE_NARRATOR


func can_accept_advance_input() -> bool:
	return Engine.get_process_frames() > last_node_change_frame


func get_active_speaker_node() -> Node:
	if active_speaker_node == null or not is_instance_valid(active_speaker_node):
		return null

	return active_speaker_node


func should_wait_for_player_continue() -> bool:
	return pending_player_continue


func consume_player_continue_request():
	pending_player_continue = false


func end():
	pending_player_continue = require_player_continue_after_end
	active = false
	current_id = -1
	current_source = ""
	dialogue_nodes.clear()
	dialogue_order.clear()
	last_node_change_frame = -1
	active_speaker_node = null
	require_player_continue_after_end = false
	GameManager.clear_active_choices()
	dialogue_ended.emit()


func _emit_current_node():
	var node = get_current_node()
	if node.is_empty():
		end()
		return

	last_node_change_frame = Engine.get_process_frames()

	var speaker = ""
	if is_current_node_npc():
		speaker = String(node.get("speaker", ""))

	var text = String(node.get("text", ""))
	var choices: Array = []
	if is_current_node_npc():
		choices = _sanitize_choices(node.get("choices", []))
		if not choices.is_empty():
			GameManager.set_active_choices(choices)
		else:
			GameManager.clear_active_choices()
	else:
		GameManager.clear_active_choices()

	dialogue_updated.emit(speaker, text, choices)


func _advance_to(next_id):
	var resolved_next_id = _normalize_node_id(next_id)
	if resolved_next_id == -1:
		end()
		return

	if not dialogue_nodes.has(resolved_next_id):
		push_error("DialogueManager could not find next dialogue id: %s" % str(next_id))
		end()
		return

	current_id = resolved_next_id
	_emit_current_node()


func _resolve_dialogue_source(dialogue_source) -> Array:
	if dialogue_source is String:
		return _load_dialogue_file(dialogue_source)

	if dialogue_source is Array:
		return dialogue_source

	push_error("Unsupported dialogue source type: %s" % typeof(dialogue_source))
	return []


func _load_dialogue_file(dialogue_path: String) -> Array:
	if dialogue_path.is_empty():
		push_error("DialogueManager received an empty dialogue path.")
		return []

	if not FileAccess.file_exists(dialogue_path):
		push_error("Dialogue file does not exist: %s" % dialogue_path)
		return []

	var file = FileAccess.open(dialogue_path, FileAccess.READ)
	if file == null:
		push_error("DialogueManager failed to open: %s" % dialogue_path)
		return []

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Dialogue JSON must be an array of nodes: %s" % dialogue_path)
		return []

	return parsed


func _build_node_map(nodes: Array) -> Dictionary:
	var node_map: Dictionary = {}

	for node in nodes:
		if typeof(node) != TYPE_DICTIONARY:
			continue

		if not node.has("id"):
			push_warning("Skipping dialogue node without an id.")
			continue

		var node_id = int(node["id"])
		node_map[node_id] = node

	return node_map


func _resolve_start_id(nodes: Array, node_map: Dictionary) -> int:
	if node_map.has(0):
		return 0

	for node in nodes:
		if typeof(node) == TYPE_DICTIONARY and node.has("id"):
			return int(node["id"])

	return -1


func _normalize_node_id(value) -> int:
	match typeof(value):
		TYPE_INT:
			return value
		TYPE_FLOAT:
			return int(value)
		TYPE_STRING:
			if String(value).is_valid_int():
				return int(value)

	return -1


func _resolve_node_type(node: Dictionary) -> String:
	if node.is_empty():
		return NODE_TYPE_NPC

	var node_type = String(node.get("type", NODE_TYPE_NPC)).to_lower()
	if node_type == NODE_TYPE_NARRATOR:
		return NODE_TYPE_NARRATOR

	if node_type != "" and node_type != NODE_TYPE_NPC:
		push_warning("Unknown dialogue node type '%s' on node id %s. Falling back to npc." % [node_type, str(node.get("id", "?"))])

	return NODE_TYPE_NPC


func _sanitize_choices(raw_choices) -> Array:
	if typeof(raw_choices) != TYPE_ARRAY:
		return []

	var choices: Array = []
	for choice in raw_choices:
		if typeof(choice) == TYPE_DICTIONARY:
			choices.append(choice)

	return choices
