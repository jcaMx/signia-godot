extends Node

signal word_started(target_word, sign_id)
signal word_progress_changed(target_word, current_input, status_message)
signal word_completed(target_word, sign_id)
signal word_cleared()

const STATUS_PROMPT := "Sign the appropriate option to choose an answer"
const STATUS_DIRECT_PROMPT := "Perform the matching sign to choose an answer"
const STATUS_INVALID := "Gesture does not match any choices. Try again."
const STATUS_CORRECT := "Correct!"

var current_level = 1
var current_npc = ""
var challenge_type = ""
var target_word = ""
var current_input = ""
var completed_tasks = []
var status_message = ""
var pending_sign_id = ""
var pending_choice_next_id = -1


func start_challenge(sign_id: String, next_id := -1):
	pending_sign_id = SignProcessor.normalize_sign_id(sign_id)
	pending_choice_next_id = int(next_id)
	challenge_type = SignProcessor.get_challenge_type(pending_sign_id)
	target_word = SignProcessor.get_challenge_target(pending_sign_id)
	current_input = ""
	status_message = STATUS_DIRECT_PROMPT
	if uses_spelling_ui():
		status_message = STATUS_PROMPT
	word_started.emit(target_word, pending_sign_id)
	_emit_progress_changed()


func start_word(sign_id: String, next_id := -1):
	start_challenge(sign_id, next_id)


func submit_letter(letter: String) -> bool:
	if not has_active_challenge() or not uses_spelling_ui():
		return false

	var normalized_letter = SignProcessor.normalize_letter_input(letter)
	if normalized_letter.is_empty():
		return false

	if current_input.length() >= target_word.length():
		return false

	var expected_letter = target_word.substr(current_input.length(), 1)
	if normalized_letter != expected_letter:
		invalid_gesture()
		return false

	current_input += normalized_letter
	status_message = "%s sign detected" % normalized_letter
	_emit_progress_changed()

	if is_word_complete():
		_complete_current_word()

	return true


func add_letter(letter: String):
	submit_letter(letter)


func submit_sign(sign_id: String) -> bool:
	if not has_active_challenge():
		return false

	if uses_spelling_ui():
		var processed_letter = SignProcessor.get_challenge_target(sign_id)
		if processed_letter.length() != 1:
			invalid_gesture()
			return false

		return submit_letter(processed_letter)

	var normalized_sign_id = SignProcessor.normalize_sign_id(sign_id)
	if normalized_sign_id != pending_sign_id:
		invalid_gesture()
		return false

	status_message = "%s sign detected" % target_word
	_emit_progress_changed()
	_complete_current_word()
	return true


func clear_input():
	if not uses_spelling_ui():
		return

	current_input = ""
	status_message = "Input cleared"
	_emit_progress_changed()


func invalid_gesture():
	status_message = STATUS_INVALID
	_emit_progress_changed()


func is_word_complete() -> bool:
	return current_input == target_word


func has_active_challenge() -> bool:
	return not pending_sign_id.is_empty()


func has_active_word() -> bool:
	return has_active_challenge()


func uses_spelling_ui() -> bool:
	return challenge_type == SignProcessor.CHALLENGE_TYPE_SPELL


func get_display_input() -> String:
	if not uses_spelling_ui() or target_word.is_empty():
		return ""

	var display_characters: Array[String] = []
	for i in range(target_word.length()):
		if i < current_input.length():
			display_characters.append(target_word.substr(i, 1))
		else:
			display_characters.append("_")

	return " ".join(display_characters)


func consume_completed_task(task_id: String) -> void:
	var normalized_task_id = String(task_id).strip_edges().to_upper()
	if normalized_task_id.is_empty():
		return

	if completed_tasks.has(normalized_task_id):
		return

	completed_tasks.append(normalized_task_id)


func cancel_word():
	challenge_type = ""
	target_word = ""
	current_input = ""
	status_message = ""
	pending_sign_id = ""
	pending_choice_next_id = -1
	word_cleared.emit()


func _complete_current_word():
	status_message = STATUS_CORRECT
	consume_completed_task(pending_sign_id)
	_emit_progress_changed()
	word_completed.emit(target_word, pending_sign_id)
	var resolved_sign_id = pending_sign_id
	cancel_word()
	DialogueManager.process_sign(resolved_sign_id)


func _emit_progress_changed():
	word_progress_changed.emit(target_word, current_input, status_message)
