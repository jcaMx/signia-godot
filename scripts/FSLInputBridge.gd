extends Node

signal sign_received(sign_id)
signal letter_received(letter)


func receive_sign(sign_id: String):
	if not DialogueManager.active and not GameManager.has_active_challenge():
		return

	sign_received.emit(sign_id)

	if GameManager.has_active_challenge():
		GameManager.submit_sign(sign_id)
		return

	DialogueManager.process_sign(sign_id)


func receive_letter(letter: String):
	if not GameManager.has_active_challenge():
		return

	var normalized_letter = SignProcessor.normalize_letter_input(letter)

	if normalized_letter.is_empty():
		return

	letter_received.emit(normalized_letter)
	GameManager.submit_letter(normalized_letter)


func on_sign_detected(sign_id: String):
	receive_sign(sign_id)
