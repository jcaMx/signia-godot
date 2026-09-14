extends Node

signal sign_detected(prediction, confidence)

@onready var http_request = $HTTPRequest
@onready var timer = $Timer
@onready var label = $Label

const API_URL = "http://127.0.0.1:5000/predict"

var stream_id = "godot-player-1"
var is_requesting := false
var last_raw_prediction := ""


func _ready():
	timer.timeout.connect(_on_timer_timeout)
	http_request.request_completed.connect(_on_request_completed)
	sign_detected.connect(FSLInputBridge.on_sign_detected)


func _on_timer_timeout():
	if is_requesting:
		return

	var payload = {
		"mode": "alphabet",
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
	print("Sending request to Flask...")
	if error != OK:
		is_requesting = false
		print("Request error:", error)


func _on_request_completed(_result, _response_code, _headers, body):
	print("Response received from Flask")
	
	is_requesting = false

	var response_text = body.get_string_from_utf8()
	print(response_text)
	var json = JSON.new()
	
	var parse_result = json.parse(response_text)

	if parse_result != OK:
		print("JSON parse failed")
		return

	var data = json.data

	var prediction = str(data.get("prediction", ""))
	var confidence = float(data.get("confidence", 0.0))
	var emitted = bool(data.get("emitted", false))
	var stabilized_prediction = str(data.get("stabilized_prediction", ""))
	var suppressed_change = bool(data.get("suppressed_change", false))
	var raw_prediction = str(data.get("raw_prediction", ""))
	var history_length = int(data.get("history_length", 0))
	var hand_detected = bool(data.get("hand_detected", false))
	var raw_confidence = float(data.get("raw_confidence", 0.0))
	var frame_source = str(data.get("frame_source", ""))

	label.text = (
		"Frame Source: " + frame_source
		#+ "\nHand: " + str(hand_detected)
		+ "\nRaw prediction: " + raw_prediction
		+ "\nRaw Conf: " + str(raw_confidence)
		#+ "\nPrediction: " + prediction
		#+ "\nEmitted: " + str(emitted)
		#+ "\nHistory: " + str(history_length)
		#+ "\nStable: " + stabilized_prediction
		#+ "\nSuppressed: " + str(suppressed_change)
	)
	if raw_prediction == "":
		last_raw_prediction = ""
	elif raw_confidence >= 0.60 and raw_prediction != last_raw_prediction:
		last_raw_prediction = raw_prediction
		print("Detected:", raw_prediction)
		sign_detected.emit(raw_prediction, raw_confidence)

	print("RAW:", raw_prediction, " FINAL:", prediction, " EMITTED:", emitted)
