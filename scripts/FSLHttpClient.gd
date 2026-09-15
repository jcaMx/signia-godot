extends Node

signal sign_detected(prediction, confidence)

@onready var http_request = $HTTPRequest
@onready var timer = $Timer
@onready var label = $Label

const API_URL = "http://127.0.0.1:5000/predict"
const MODELS_URL = "http://127.0.0.1:5000/models"

# Cadence settings
const POLL_INTERVAL_ALPHABET := 0.25   # Static single-frame letters (~4 FPS)
const POLL_INTERVAL_GESTURE  := 0.08   # Dynamic 30-frame sequence gestures (~12.5 FPS -> 30 frames in 2.4s)

var stream_id = "godot-player-1"
var is_requesting := false
var last_raw_prediction := ""
var current_active_mode := "alphabet"
var catalog_request: HTTPRequest = null


func _ready():
	timer.timeout.connect(_on_timer_timeout)
	http_request.request_completed.connect(_on_request_completed)
	sign_detected.connect(FSLInputBridge.on_sign_detected)
	fetch_backend_catalog()


func fetch_backend_catalog():
	catalog_request = HTTPRequest.new()
	add_child(catalog_request)
	catalog_request.request_completed.connect(_on_catalog_response)
	var err = catalog_request.request(MODELS_URL)
	if err != OK:
		push_warning("[FSLHttpClient] Could not initiate GET /models request. Error: %d" % err)


func _on_catalog_response(_result, response_code, _headers, body):
	if response_code == 200:
		var response_text = body.get_string_from_utf8()
		var json = JSON.new()
		if json.parse(response_text) == OK and typeof(json.data) == TYPE_DICTIONARY:
			SignProcessor.update_catalog_from_backend(json.data)
	else:
		print("[FSLHttpClient] Server returned code %d for /models. Relying on cached catalog." % response_code)

	if catalog_request != null and is_instance_valid(catalog_request):
		catalog_request.queue_free()
		catalog_request = null


func get_active_backend_mode() -> String:
	if GameManager.has_active_challenge():
		return SignProcessor.get_backend_mode_for_sign(GameManager.pending_sign_id)

	if GameManager.has_active_choices() and not GameManager.active_choices.is_empty():
		var first_choice = GameManager.active_choices[0]
		if typeof(first_choice) == TYPE_DICTIONARY:
			var sign_val = String(first_choice.get("sign", ""))
			return SignProcessor.get_backend_mode_for_sign(sign_val)

	return "alphabet"


func _on_timer_timeout():
	if is_requesting:
		return

	var target_mode = get_active_backend_mode()

	# Dynamically adjust polling rate based on mode (Alphabet vs 30-frame Gestures)
	if target_mode != current_active_mode:
		current_active_mode = target_mode
		last_raw_prediction = ""
		if current_active_mode == "alphabet":
			timer.wait_time = POLL_INTERVAL_ALPHABET
		else:
			timer.wait_time = POLL_INTERVAL_GESTURE

	var payload = {
		"mode": current_active_mode,
		"frame_source": "server",
		"stabilize": true,
		"stream_id": stream_id
	}

	var json_body = JSON.stringify(payload)
	var headers = ["Content-Type: application/json"]

	is_requesting = true

	var error = http_request.request(
		API_URL,
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)
	if error != OK:
		is_requesting = false
		print("Request error:", error)


func _on_request_completed(_result, _response_code, _headers, body):
	is_requesting = false

	var response_text = body.get_string_from_utf8()
	var json = JSON.new()

	var parse_result = json.parse(response_text)
	if parse_result != OK:
		return

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return

	var prediction = str(data.get("prediction", ""))
	var raw_prediction = str(data.get("raw_prediction", ""))
	var raw_confidence = float(data.get("raw_confidence", 0.0))
	var mode = str(data.get("mode", ""))
	var frame_source = str(data.get("frame_source", ""))
	var buffer_size = int(data.get("buffer_size", 0))
	var buffer_msg = str(data.get("message", ""))

	# Update Debug UI
	if label != null:
		var status_info = ""
		if mode != "alphabet" and raw_prediction == "":
			if buffer_msg != "":
				status_info = "\nStatus: " + buffer_msg
			elif buffer_size > 0:
				status_info = "\nBuffering: %d/30 frames" % buffer_size

		label.text = (
			"Mode: " + mode
			+ "\nFrame Source: " + frame_source
			+ "\nRaw prediction: " + raw_prediction
			+ "\nRaw Conf: " + str(raw_confidence)
			+ status_info
		)

	if raw_prediction == "":
		last_raw_prediction = ""
	elif raw_confidence >= 0.60 and raw_prediction != last_raw_prediction:
		last_raw_prediction = raw_prediction
		print("Detected [%s]: %s (Conf: %.2f)" % [mode, raw_prediction, raw_confidence])
		sign_detected.emit(raw_prediction, raw_confidence)
