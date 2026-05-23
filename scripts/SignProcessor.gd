extends Node

const SPELL_PREFIX := "SPELL_"
const DIRECT_SIGN_PREFIX := "SIGN_"

const CHALLENGE_TYPE_SPELL := "spell"
const CHALLENGE_TYPE_DIRECT := "direct"


func process_sign(sign_id: String) -> String:
	return get_challenge_target(sign_id)


func normalize_sign_id(sign_id: String) -> String:
	return String(sign_id).strip_edges().to_upper()


func get_challenge_type(sign_id: String) -> String:

	var normalized_sign = normalize_sign_id(sign_id)

	if normalized_sign.begins_with(SPELL_PREFIX):
		return CHALLENGE_TYPE_SPELL

	if normalized_sign.begins_with(DIRECT_SIGN_PREFIX):
		return CHALLENGE_TYPE_DIRECT

	return CHALLENGE_TYPE_DIRECT


func get_challenge_target(sign_id: String) -> String:

	var normalized_sign = normalize_sign_id(sign_id)

	if normalized_sign.begins_with(SPELL_PREFIX):
		return normalized_sign.trim_prefix(SPELL_PREFIX)

	if normalized_sign.begins_with(DIRECT_SIGN_PREFIX):
		return normalized_sign.trim_prefix(DIRECT_SIGN_PREFIX)

	return normalized_sign


func normalize_letter_input(raw_input: String) -> String:

	var normalized_input = String(raw_input).strip_edges().to_upper()

	if normalized_input.length() != 1:
		return ""

	var code = normalized_input.unicode_at(0)

	if code < 65 or code > 90:
		return ""

	return normalized_input
