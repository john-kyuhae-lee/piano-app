extends Node
## Captures viewport screenshots on game state transitions.
## Enabled only when the game is launched with: godot --path . -- --capture

var _enabled: bool = false
var _capture_dir: String = "user://captures/"
var _game_engine: GameEngine
var _first_clear_captured: bool = false
var _playing_captured: bool = false


func _ready() -> void:
	if not &"--capture" in OS.get_cmdline_user_args():
		return

	_enabled = true

	# Ensure capture directory exists
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(_capture_dir),
	)

	Events.game_state_changed.connect(_on_state_changed)
	Events.note_cleared.connect(_on_note_cleared)

	# Capture initial Ready state after one frame (so viewport is rendered)
	_capture_deferred.call_deferred(&"ready")


func _process(_delta: float) -> void:
	if not _enabled:
		return

	# Find GameEngine on first frame
	if _game_engine == null:
		var engine: Node = get_tree().root.find_child("GameEngine", true, false)
		if engine is GameEngine:
			_game_engine = engine as GameEngine

	# Capture first frame of Playing state
	if not _playing_captured and _game_engine != null:
		if _game_engine.state == GameEngine.State.PLAYING:
			_playing_captured = true
			capture(&"playing")


## Public method — can be called from other scripts or the test harness.
func capture(label: StringName) -> void:
	if not _enabled:
		return

	var image: Image = get_viewport().get_texture().get_image()
	if image == null:
		push_warning("DebugCapture: Could not get viewport image")
		return

	var frame: int = Engine.get_frames_drawn()
	var filename: String = "%s%06d_%s.png" % [_capture_dir, frame, label]
	var err: Error = image.save_png(filename)
	if err != OK:
		push_warning("DebugCapture: Failed to save " + filename)
	else:
		var global_path: String = ProjectSettings.globalize_path(filename)
		print("CAPTURE: " + global_path)


func _capture_deferred(label: StringName) -> void:
	# Wait one more frame so the viewport has actually rendered
	await get_tree().process_frame
	capture(label)


func _on_state_changed(state: int) -> void:
	match state:
		GameEngine.State.COMPLETE:
			capture(&"complete")


func _on_note_cleared(_pitch: int) -> void:
	if not _first_clear_captured:
		_first_clear_captured = true
		capture(&"first_clear")
