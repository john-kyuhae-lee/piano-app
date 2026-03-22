extends Node2D
## Main scene — composes keyboard, note renderer, game engine, and UI.

var _keyboard: PianoKeyboard
var _note_renderer: NoteRenderer
var _game_engine: GameEngine
var _status_label: Label
var _state_label: Label


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.08, 0.08, 0.1))

	_keyboard = PianoKeyboard.new()
	_keyboard.name = "Keyboard"
	add_child(_keyboard)

	_game_engine = GameEngine.new()
	_game_engine.name = "GameEngine"
	add_child(_game_engine)

	# Load song from --song arg or use fallback
	_load_song()

	_note_renderer = NoteRenderer.new()
	_note_renderer.name = "NoteRenderer"
	add_child(_note_renderer)

	# Wire up after children are ready
	_note_renderer.setup.call_deferred(_keyboard, _game_engine)

	# MIDI connection status (top-left)
	_status_label = Label.new()
	_status_label.name = "MidiStatus"
	_status_label.position = Vector2(20.0, 16.0)
	_status_label.add_theme_font_size_override(&"font_size", 20)
	_status_label.add_theme_color_override(&"font_color", Color(0.6, 0.6, 0.6))
	_status_label.text = "No MIDI device"
	add_child(_status_label)

	Events.midi_device_connected.connect(_on_device_connected)
	Events.midi_device_disconnected.connect(_on_device_disconnected)

	# Game state label (centered)
	_state_label = Label.new()
	_state_label.name = "StateLabel"
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_state_label.add_theme_font_size_override(&"font_size", 48)
	_state_label.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, 0.9))
	add_child(_state_label)

	Events.game_state_changed.connect(_on_game_state_changed)

	# Show initial state
	_update_state_label(GameEngine.State.READY)


func _process(_delta: float) -> void:
	# Keep state label centered
	if _state_label.text != "":
		var vp: Vector2 = get_viewport_rect().size
		_state_label.position = Vector2(
			(vp.x - _state_label.size.x) / 2.0,
			vp.y * 0.35,
		)


func _on_device_connected(device_name: String) -> void:
	_status_label.text = "Connected: " + device_name
	_status_label.add_theme_color_override(&"font_color", Color(0.4, 0.9, 0.5))


func _on_device_disconnected() -> void:
	_status_label.text = "No MIDI device"
	_status_label.add_theme_color_override(&"font_color", Color(0.6, 0.6, 0.6))


func _on_game_state_changed(state: int) -> void:
	_update_state_label(state as GameEngine.State)


func _load_song() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var song_path: String = ""
	for i: int in range(args.size()):
		if args[i] == "--song" and i + 1 < args.size():
			song_path = args[i + 1]
			break

	if song_path != "":
		var song_data: Dictionary = SongLoader.load_song(song_path)
		if not song_data.is_empty():
			_game_engine.load_song(song_data)
			var title: String = song_data.get("meta", {}).get("title", "Unknown") as String
			print("Loaded song: " + title)
		else:
			push_warning("Failed to load song, using fallback")
			_game_engine.use_fallback()
	else:
		_game_engine.use_fallback()


func _update_state_label(state: GameEngine.State) -> void:
	match state:
		GameEngine.State.READY:
			_state_label.text = "Press any key to start"
			_state_label.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, 0.7))
		GameEngine.State.PLAYING:
			_state_label.text = ""
		GameEngine.State.COMPLETE:
			_state_label.text = "Song Complete!"
			_state_label.add_theme_color_override(&"font_color", Color(0.4, 0.95, 0.5, 0.95))
