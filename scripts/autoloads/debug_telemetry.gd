extends Node
## Writes structured JSONL telemetry to user://debug_telemetry.jsonl.
## Enabled only when the game is launched with: godot --path . -- --telemetry

var _enabled: bool = false
var _file: FileAccess
var _frame_count: int = 0
var _heartbeat_interval: int = 30
var _game_engine: GameEngine
var _start_time_ms: float
var _notes_cleared: int = 0
var _wrong_notes: int = 0
var _fps_samples: Array[float] = []


func _ready() -> void:
	if not &"--telemetry" in OS.get_cmdline_user_args():
		return

	_enabled = true
	_start_time_ms = Time.get_ticks_msec()

	# Clear previous telemetry
	var path: String = "user://debug_telemetry.jsonl"
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_error("DebugTelemetry: Could not open " + path)
		_enabled = false
		return

	# Connect to Events bus
	Events.midi_note_on.connect(_on_midi_note_on)
	Events.note_cleared.connect(_on_note_cleared)
	Events.wrong_note_played.connect(_on_wrong_note)
	Events.song_completed.connect(_on_song_completed)
	Events.game_state_changed.connect(_on_state_changed)

	_log_event("telemetry_start", {})


func _process(_delta: float) -> void:
	if not _enabled:
		return

	_frame_count += 1

	# Find GameEngine on first frame (deferred setup)
	if _game_engine == null:
		var engine: Node = get_tree().root.find_child("GameEngine", true, false)
		if engine is GameEngine:
			_game_engine = engine as GameEngine

	# Heartbeat
	if _frame_count % _heartbeat_interval == 0:
		var fps: float = Engine.get_frames_per_second()
		_fps_samples.append(fps)
		_log_event("heartbeat", {"fps": fps})


func _exit_tree() -> void:
	if _file != null:
		_file.close()


func _log_event(event_type: String, data: Dictionary) -> void:
	if _file == null:
		return

	var entry: Dictionary = {
		"frame": _frame_count,
		"timestamp_ms": Time.get_ticks_msec() - _start_time_ms,
		"event": event_type,
		"fps": Engine.get_frames_per_second(),
	}

	if _game_engine != null:
		entry["song_time"] = snappedf(_game_engine.song_time, 0.001)
		entry["state"] = GameEngine.State.keys()[_game_engine.state]
		entry["cleared_count"] = _game_engine.cleared_notes.size()
		entry["waiting"] = _game_engine._waiting

	entry.merge(data)
	_file.store_line(JSON.stringify(entry))
	_file.flush()


func _on_midi_note_on(pitch: int, velocity: int) -> void:
	_log_event("midi_note_on", {"pitch": pitch, "velocity": velocity})


func _on_note_cleared(pitch: int) -> void:
	_notes_cleared += 1
	_log_event("note_cleared", {"pitch": pitch})


func _on_wrong_note() -> void:
	_wrong_notes += 1
	_log_event("wrong_note", {})


func _on_song_completed() -> void:
	var summary: Dictionary = {
		"total_notes_cleared": _notes_cleared,
		"total_wrong_notes": _wrong_notes,
		"total_frames": _frame_count,
		"elapsed_ms": Time.get_ticks_msec() - _start_time_ms,
	}
	if _fps_samples.size() > 0:
		var min_fps: float = _fps_samples[0]
		var max_fps: float = _fps_samples[0]
		var sum_fps: float = 0.0
		for fps: float in _fps_samples:
			min_fps = minf(min_fps, fps)
			max_fps = maxf(max_fps, fps)
			sum_fps += fps
		summary["min_fps"] = min_fps
		summary["max_fps"] = max_fps
		summary["avg_fps"] = snappedf(sum_fps / float(_fps_samples.size()), 0.1)

	_log_event("song_completed", summary)


func _on_state_changed(state: int) -> void:
	_log_event("state_changed", {"new_state": GameEngine.State.keys()[state]})
