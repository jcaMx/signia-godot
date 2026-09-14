extends Node

signal word_started(target_word, sign_id)
signal word_progress_changed(target_word, current_input, status_message)
signal word_completed(target_word, sign_id)
signal word_cleared()
signal chapter_finished(level_id)

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
var chapter_is_finished := false
var active_choices: Array = []

func set_active_choices(choices: Array):
	active_choices = choices
	current_input = ""
	pending_sign_id = ""
	pending_choice_next_id = -1
	if not active_choices.is_empty():
		status_message = STATUS_PROMPT
		word_started.emit("", "")
		_emit_progress_changed()


func clear_active_choices():
	active_choices.clear()
	current_input = ""
	status_message = ""
	word_cleared.emit()


func has_active_choices() -> bool:
	return not active_choices.is_empty()


func select_choice(choice: Dictionary):
	if typeof(choice) == TYPE_DICTIONARY and not choice.is_empty():
		_complete_choice(choice)


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
	var normalized_letter = SignProcessor.normalize_letter_input(letter)
	if normalized_letter.is_empty():
		return false

	if has_active_challenge() and uses_spelling_ui():
		if current_input.length() >= target_word.length():
			return false

		var expected_letter = target_word.substr(current_input.length(), 1)
		if normalized_letter != expected_letter:
			invalid_gesture()
			return false

		current_input += normalized_letter
		#AudioManager.play_correct()
		status_message = "%s sign detected" % normalized_letter
		_emit_progress_changed()

		if is_word_complete():
			_complete_current_word()

		return true

	if has_active_choices():
		var candidate_input = current_input + normalized_letter
		var matched_choice: Dictionary = {}
		var has_partial_match := false

		for choice in active_choices:
			if typeof(choice) != TYPE_DICTIONARY:
				continue

			var sign_id = String(choice.get("sign", ""))
			var target = SignProcessor.get_challenge_target(sign_id)
			var ctype = SignProcessor.get_challenge_type(sign_id)

			if ctype == SignProcessor.CHALLENGE_TYPE_SPELL:
				if target.begins_with(candidate_input):
					has_partial_match = true
					if candidate_input == target:
						matched_choice = choice
						break
			else:
				if target == normalized_letter or target == candidate_input:
					matched_choice = choice
					break

		if not matched_choice.is_empty():
			current_input = candidate_input
			_complete_choice(matched_choice)
			return true

		if has_partial_match:
			current_input = candidate_input
			status_message = "%s sign detected" % normalized_letter
			_emit_progress_changed()
			return true

		invalid_gesture()
		return false

	return false


func add_letter(letter: String):
	submit_letter(letter)


func submit_sign(sign_id: String) -> bool:
	if has_active_challenge():
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

	if has_active_choices():
		var normalized_sign = SignProcessor.normalize_sign_id(sign_id)
		var letter = SignProcessor.get_challenge_target(normalized_sign)
		if letter.length() == 1 and SignProcessor.normalize_letter_input(letter) != "":
			return submit_letter(letter)

		for choice in active_choices:
			if typeof(choice) != TYPE_DICTIONARY:
				continue
			var choice_sign = SignProcessor.normalize_sign_id(String(choice.get("sign", "")))
			var target = SignProcessor.get_challenge_target(choice_sign)

			if choice_sign == normalized_sign or target == normalized_sign:
				_complete_choice(choice)
				return true

		invalid_gesture()
		return false

	return false


func clear_input():
	if not uses_spelling_ui() and not has_active_choices():
		return

	current_input = ""
	status_message = "Input cleared"
	_emit_progress_changed()


func invalid_gesture():
	#AudioManager.play_wrong()
	status_message = STATUS_INVALID
	_emit_progress_changed()


func is_word_complete() -> bool:
	return current_input == target_word


func has_active_challenge() -> bool:
	return not pending_sign_id.is_empty()


func has_active_word() -> bool:
	return has_active_challenge() or has_active_choices()


func uses_spelling_ui() -> bool:
	return challenge_type == SignProcessor.CHALLENGE_TYPE_SPELL


func uses_direct_sign_ui() -> bool:
	return challenge_type == SignProcessor.CHALLENGE_TYPE_DIRECT


func get_display_input() -> String:
	if has_active_challenge():
		if target_word.is_empty():
			return ""

		if uses_direct_sign_ui():
			return target_word

		if not uses_spelling_ui():
			return ""

		var display_characters: Array[String] = []
		for i in range(target_word.length()):
			if i < current_input.length():
				display_characters.append(target_word.substr(i, 1))
			else:
				display_characters.append("_")

		return " ".join(display_characters)

	if has_active_choices():
		if current_input.is_empty():
			return "_ _ _"

		var max_len = 0
		for choice in active_choices:
			if typeof(choice) != TYPE_DICTIONARY:
				continue
			var sign_id = String(choice.get("sign", ""))
			var target = SignProcessor.get_challenge_target(sign_id)
			if target.begins_with(current_input):
				max_len = max(max_len, target.length())

		if max_len <= 0:
			max_len = current_input.length()

		var display_characters: Array[String] = []
		for i in range(max_len):
			if i < current_input.length():
				display_characters.append(current_input.substr(i, 1))
			else:
				display_characters.append("_")

		return " ".join(display_characters)

	return ""


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
	active_choices.clear()
	word_cleared.emit()


func _complete_choice(choice: Dictionary):
	var sign_id = String(choice.get("sign", ""))
	var target = SignProcessor.get_challenge_target(sign_id)

	status_message = STATUS_CORRECT
	consume_completed_task(sign_id)
	_emit_progress_changed()
	word_completed.emit(target, sign_id)

	active_choices.clear()
	current_input = ""
	pending_sign_id = ""
	pending_choice_next_id = -1
	word_cleared.emit()

	DialogueManager.process_sign(sign_id)


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


func finish_chapter():
	if chapter_is_finished:
		return

	chapter_is_finished = true
	chapter_finished.emit(LevelManager.current_level)
