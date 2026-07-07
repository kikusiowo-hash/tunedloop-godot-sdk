# TunedLoop Godot SDK v1.0.0
# Register this script as an Autoload singleton named `TunedLoop`.
extends Node

signal difficulty_adjusted(modifiers: Dictionary)

const SDK_VERSION: String = "1.0.0"
const TELEMETRY_ENDPOINT: String = "https://api.tunedloop.com/v1/events"
const FLUSH_INTERVAL_SECONDS: float = 10.0
const REQUEST_TIMEOUT_SECONDS: float = 8.0
const MAX_BATCH_SIZE: int = 50
const MAX_QUEUE_SIZE: int = 500
const SESSION_CONFIG_PATH: String = "user://tuned_loop_session.cfg"
const SESSION_SECTION: String = "session"
const SESSION_KEY: String = "id"

@export var api_key: String = ""
@export var game_id: String = ""
@export var game_version: String = ""
@export var environment: String = "production"
@export var auto_start: bool = true
@export var debug_logging: bool = false

var _event_queue: Array[Dictionary] = []
var _session_id: String = ""
var _flush_timer: Timer
var _is_flushing: bool = false
var _shutdown_started: bool = false


func _ready() -> void:
	# Developers usually set TunedLoop.api_key from their own _ready() before events begin.
	# Example: TunedLoop.api_key = "tl_live_your_key"
	randomize()
	_session_id = _resolve_session_id()
	_ensure_flush_timer()

	if auto_start and _flush_timer != null:
		_flush_timer.start()

	_log("ready session=%s" % _session_id)


func _exit_tree() -> void:
	_shutdown_started = true
	if _flush_timer != null and is_instance_valid(_flush_timer):
		_flush_timer.stop()


func track_event(event_type: String, data: Dictionary = {}) -> void:
	var clean_event_type := event_type.strip_edges()
	if clean_event_type.is_empty():
		return

	var event_data := data.duplicate(true)
	var event := {
		"event_type": clean_event_type,
		"data": event_data,
		"timestamp": Time.get_datetime_string_from_system(true),
		"session_id": _session_id,
		"sequence": _event_queue.size() + 1,
	}

	_event_queue.append(event)
	_trim_queue_if_needed()
	_log("queued %s (%d)" % [clean_event_type, _event_queue.size()])

	if _event_queue.size() >= MAX_BATCH_SIZE:
		_flush_events()


func flush_now() -> void:
	_flush_events()


func set_api_key(value: String) -> void:
	api_key = value.strip_edges()


func get_session_id() -> String:
	return _session_id


func _ensure_flush_timer() -> void:
	if _flush_timer != null and is_instance_valid(_flush_timer):
		return

	_flush_timer = Timer.new()
	_flush_timer.name = "TunedLoopFlushTimer"
	_flush_timer.wait_time = FLUSH_INTERVAL_SECONDS
	_flush_timer.one_shot = false
	_flush_timer.autostart = false
	_flush_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_flush_timer.timeout.connect(_flush_events)
	add_child(_flush_timer)


func _flush_events() -> void:
	if _shutdown_started or _is_flushing:
		return
	if _event_queue.is_empty():
		return
	if api_key.strip_edges().is_empty():
		_log("skip flush without api_key")
		return

	_is_flushing = true
	var batch := _drain_batch()
	var payload := _build_payload(batch)
	var body := JSON.stringify(payload)
	var request := HTTPRequest.new()
	request.name = "TunedLoopHTTPRequest"
	request.timeout = REQUEST_TIMEOUT_SECONDS
	request.use_threads = true
	request.request_completed.connect(_on_request_completed.bind(request, batch), CONNECT_ONE_SHOT)
	add_child(request)

	var headers := [
		"Content-Type: application/json",
		"Accept: application/json",
		"Authorization: Bearer %s" % api_key.strip_edges(),
		"X-TunedLoop-SDK: godot-%s" % SDK_VERSION,
	]

	var error := request.request(TELEMETRY_ENDPOINT, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		_requeue_front(batch)
		_cleanup_request(request)
		_is_flushing = false


func _drain_batch() -> Array[Dictionary]:
	var batch_size: int = min(MAX_BATCH_SIZE, _event_queue.size())
	var batch: Array[Dictionary] = []
	for index in range(batch_size):
		batch.append(_event_queue[index])
	_event_queue = _event_queue.slice(batch_size)
	return batch


func _build_payload(batch: Array[Dictionary]) -> Dictionary:
	return {
		"api_key": api_key.strip_edges(),
		"sdk": "godot",
		"sdk_version": SDK_VERSION,
		"session_id": _session_id,
		"game_id": _value_or_project_name(game_id),
		"game_version": game_version,
		"environment": environment,
		"engine": _engine_info(),
		"events": batch,
	}


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest, batch: Array[Dictionary]) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_requeue_front(batch)
		_cleanup_after_request(request)
		return

	var response_text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(response_text) if not response_text.is_empty() else {}
	if typeof(parsed) == TYPE_DICTIONARY:
		_emit_modifiers_from_response(parsed)

	_cleanup_after_request(request)


func _emit_modifiers_from_response(response: Dictionary) -> void:
	var modifiers: Dictionary = {}
	if response.has("modifiers") and typeof(response["modifiers"]) == TYPE_DICTIONARY:
		modifiers = response["modifiers"]
	elif response.has("difficulty_modifiers") and typeof(response["difficulty_modifiers"]) == TYPE_DICTIONARY:
		modifiers = response["difficulty_modifiers"]
	elif response.has("adjustments") and typeof(response["adjustments"]) == TYPE_DICTIONARY:
		modifiers = response["adjustments"]

	if not modifiers.is_empty():
		difficulty_adjusted.emit(modifiers.duplicate(true))


func _cleanup_after_request(request: HTTPRequest) -> void:
	_cleanup_request(request)
	_is_flushing = false
	if _event_queue.size() >= MAX_BATCH_SIZE:
		call_deferred("_flush_events")


func _cleanup_request(request: HTTPRequest) -> void:
	if request != null and is_instance_valid(request):
		request.queue_free()


func _requeue_front(batch: Array[Dictionary]) -> void:
	if batch.is_empty():
		return
	_event_queue = batch + _event_queue
	_trim_queue_if_needed()


func _trim_queue_if_needed() -> void:
	if _event_queue.size() <= MAX_QUEUE_SIZE:
		return
	var overflow := _event_queue.size() - MAX_QUEUE_SIZE
	_event_queue = _event_queue.slice(overflow)


func _resolve_session_id() -> String:
	var unique_id := OS.get_unique_id().strip_edges()
	if not unique_id.is_empty():
		return unique_id

	var config := ConfigFile.new()
	var load_error := config.load(SESSION_CONFIG_PATH)
	if load_error == OK:
		var saved_id := str(config.get_value(SESSION_SECTION, SESSION_KEY, "")).strip_edges()
		if not saved_id.is_empty():
			return saved_id

	var fallback_id := _create_fallback_session_id()
	config.set_value(SESSION_SECTION, SESSION_KEY, fallback_id)
	config.save(SESSION_CONFIG_PATH)
	return fallback_id


func _create_fallback_session_id() -> String:
	var unix_time := int(Time.get_unix_time_from_system())
	var random_part := "%08x%08x" % [randi(), randi()]
	return "tl_%d_%s" % [unix_time, random_part]


func _value_or_project_name(value: String) -> String:
	var clean_value := value.strip_edges()
	if not clean_value.is_empty():
		return clean_value
	return str(ProjectSettings.get_setting("application/config/name", "godot_game"))


func _engine_info() -> Dictionary:
	var version := Engine.get_version_info()
	return {
		"name": "Godot",
		"major": version.get("major", 4),
		"minor": version.get("minor", 0),
		"patch": version.get("patch", 0),
		"status": version.get("status", "stable"),
	}


func _log(message: String) -> void:
	if debug_logging:
		print("[TunedLoop] %s" % message)
