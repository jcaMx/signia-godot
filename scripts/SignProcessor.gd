extends Node

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
const SPELL_PREFIX := "SPELL_"
const DIRECT_SIGN_PREFIX := "SIGN_"
const DIRECT_SIGN_SUFFIX := "_SIGN"

const CHALLENGE_TYPE_SPELL := "spell"
const CHALLENGE_TYPE_DIRECT := "direct"

const RESOLVE_URL := "http://127.0.0.1:5000/resolve_mode?sign="

# Built-in base mappings (immediate startup defaults & offline fallback)
const DEFAULT_CATEGORY_MAP := {
	"GOOD_MORNING": "greeting",
	"GOOD_AFTERNOON": "greeting",
	"GOOD_EVENING": "greeting",
	"HELLO": "greeting",
	"HOW_ARE_YOU": "greeting",
	"IM_FINE": "greeting",
	"NICE_TO_MEET_YOU": "greeting",
	"THANK_YOU": "greeting",
	"YOURE_WELCOME": "greeting",
	"SEE_YOU_TOMORROW": "greeting",
	
	"UNDERSTAND": "survival",
	"DONT_UNDERSTAND": "survival",
	"KNOW": "survival",
	"DONT_KNOW": "survival",
	"NO": "survival",
	"YES": "survival",
	"WRONG": "survival",
	"CORRECT": "survival",
	"SLOW": "survival",
	"FAST": "survival"
}

# -----------------------------------------------------------------------------
# State & Signals
# -----------------------------------------------------------------------------
var category_map: Dictionary = {}
var available_categories: Array = ["alphabet", "greeting", "survival"]
var is_initialized := false

signal registry_updated


func _ready() -> void:
	category_map = DEFAULT_CATEGORY_MAP.duplicate()
	load_cached_registry()


# -----------------------------------------------------------------------------
# Core Normalization & Matching API
# -----------------------------------------------------------------------------

func normalize_sign_id(sign_id: String) -> String:
	return String(sign_id).strip_edges().to_upper().replace(" ", "_").replace("'", "").replace("’", "")


func get_challenge_target(sign_id: String) -> String:
	var normalized = normalize_sign_id(sign_id)

	if normalized.begins_with(SPELL_PREFIX):
		return normalized.trim_prefix(SPELL_PREFIX)
	if normalized.begins_with(DIRECT_SIGN_PREFIX):
		normalized = normalized.trim_prefix(DIRECT_SIGN_PREFIX)
	if normalized.ends_with(DIRECT_SIGN_SUFFIX):
		normalized = normalized.trim_suffix(DIRECT_SIGN_SUFFIX)

	return normalized


func get_challenge_type(sign_id: String) -> String:
	var normalized = normalize_sign_id(sign_id)
	if normalized.begins_with(SPELL_PREFIX):
		return CHALLENGE_TYPE_SPELL
	return CHALLENGE_TYPE_DIRECT


func get_backend_mode_for_sign(sign_id: String) -> String:
	if get_challenge_type(sign_id) == CHALLENGE_TYPE_SPELL:
		return "alphabet"

	var target = get_challenge_target(sign_id)
	return category_map.get(target, "alphabet")


func are_signs_matching(detected_sign: String, target_sign: String) -> bool:
	var norm_detected = get_challenge_target(detected_sign)
	var norm_target = get_challenge_target(target_sign)
	return norm_detected == norm_target


func normalize_letter_input(raw_input: String) -> String:
	var normalized_input = String(raw_input).strip_edges().to_upper()

	if normalized_input.length() != 1:
		return ""

	var code = normalized_input.unicode_at(0)
	if code < 65 or code > 90:
		return ""

	return normalized_input


# -----------------------------------------------------------------------------
# On-Demand & Dynamic Backend Resolution
# -----------------------------------------------------------------------------

## Resolves the mode for sign_id asynchronously from backend if not already cached.
func resolve_mode_from_backend(sign_id: String, callback: Callable) -> void:
	if get_challenge_type(sign_id) == CHALLENGE_TYPE_SPELL:
		callback.call("alphabet")
		return

	var target = get_challenge_target(sign_id)

	# If already cached locally, return immediately
	if category_map.has(target):
		callback.call(category_map[target])
		return

	# Query backend dynamically
	var req = HTTPRequest.new()
	add_child(req)

	req.request_completed.connect(func(_result, code, _headers, body):
		var resolved_mode = "alphabet"
		if code == 200:
			var parsed = JSON.parse_string(body.get_string_from_utf8())
			if typeof(parsed) == TYPE_DICTIONARY and parsed.has("mode"):
				resolved_mode = String(parsed["mode"]).to_lower()
				category_map[target] = resolved_mode

		req.queue_free()
		callback.call(resolved_mode)
	)

	var error = req.request(RESOLVE_URL + sign_id.uri_encode())
	if error != OK:
		req.queue_free()
		callback.call(category_map.get(target, "alphabet"))


# -----------------------------------------------------------------------------
# Dynamic Catalog Ingestion & Local Persistence
# -----------------------------------------------------------------------------

func update_catalog_from_backend(catalog_data: Dictionary) -> void:
	var categories_dict = catalog_data.get("categories", {})
	if typeof(categories_dict) != TYPE_DICTIONARY:
		return

	for category_name in categories_dict.keys():
		var cat_str = String(category_name).to_lower()
		if not available_categories.has(cat_str):
			available_categories.append(cat_str)

		var labels = categories_dict[category_name]
		if typeof(labels) == TYPE_ARRAY:
			for label in labels:
				var normalized_key = normalize_sign_id(String(label))
				category_map[normalized_key] = cat_str

	is_initialized = true
	save_cached_registry(catalog_data)
	registry_updated.emit()
	print("[SignProcessor] Catalog updated: %d signs across %d categories." % [category_map.size(), available_categories.size()])


func save_cached_registry(data: Dictionary) -> void:
	var file = FileAccess.open("user://catalog_cache.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))


func load_cached_registry() -> void:
	if not FileAccess.file_exists("user://catalog_cache.json"):
		return

	var file = FileAccess.open("user://catalog_cache.json", FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			update_catalog_from_backend(parsed)
