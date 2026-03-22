extends Node2D
## Main scene — song browser + gameplay. Shows song list by default,
## switches to gameplay when a song is selected.

var _keyboard: PianoKeyboard
var _note_renderer: NoteRenderer
var _game_engine: GameEngine
var _status_label: Label
var _state_label: Label
var _song_list: SongListUI
var _in_game: bool = false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.08, 0.08, 0.1))

	# Game nodes (hidden until a song is selected)
	_keyboard = PianoKeyboard.new()
	_keyboard.name = "Keyboard"
	_keyboard.visible = false
	add_child(_keyboard)

	_game_engine = GameEngine.new()
	_game_engine.name = "GameEngine"
	add_child(_game_engine)

	_note_renderer = NoteRenderer.new()
	_note_renderer.name = "NoteRenderer"
	_note_renderer.visible = false
	add_child(_note_renderer)

	_note_renderer.setup.call_deferred(_keyboard, _game_engine)

	# MIDI status (always visible)
	_status_label = Label.new()
	_status_label.name = "MidiStatus"
	_status_label.position = Vector2(20.0, 16.0)
	_status_label.add_theme_font_size_override(&"font_size", 20)
	_status_label.add_theme_color_override(&"font_color", Color(0.6, 0.6, 0.6))
	_status_label.text = "No MIDI device"
	_status_label.z_index = 10
	add_child(_status_label)

	Events.midi_device_connected.connect(_on_device_connected)
	Events.midi_device_disconnected.connect(_on_device_disconnected)

	# State label (game mode)
	_state_label = Label.new()
	_state_label.name = "StateLabel"
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_state_label.add_theme_font_size_override(&"font_size", 48)
	_state_label.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, 0.9))
	_state_label.visible = false
	add_child(_state_label)

	Events.game_state_changed.connect(_on_game_state_changed)

	# Check for --song command line arg (direct play mode)
	var song_path: String = _get_arg("--song")
	if song_path != "":
		_start_game_with_file(song_path)
	else:
		_show_song_list()


func _process(_delta: float) -> void:
	if _in_game and _state_label.visible and _state_label.text != "":
		var vp: Vector2 = get_viewport_rect().size
		_state_label.position = Vector2(
			(vp.x - _state_label.size.x) / 2.0,
			vp.y * 0.35,
		)


func _input(event: InputEvent) -> void:
	# ESC returns to song list from game
	if _in_game and event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			_show_song_list()


func _show_song_list() -> void:
	_in_game = false
	_keyboard.visible = false
	_note_renderer.visible = false
	_state_label.visible = false

	if _song_list != null:
		_song_list.visible = true
	else:
		# Control nodes need a CanvasLayer to render on top of Node2D
		var canvas_layer := CanvasLayer.new()
		canvas_layer.name = "UILayer"
		canvas_layer.layer = 10
		add_child(canvas_layer)

		_song_list = SongListUI.new()
		_song_list.name = "SongList"
		_song_list.song_selected.connect(_on_song_selected)
		canvas_layer.add_child(_song_list)


func _on_song_selected(song: Dictionary) -> void:
	var file_path: String = song.get("file_path", "") as String
	var song_id: String = song.get("id", "") as String

	if file_path == "":
		push_warning("No file_path in song data")
		return

	# Check if already prepared
	var json_path: String = "songs/" + song_id + ".json"
	var global_json: String = ProjectSettings.globalize_path("res://" + json_path)

	if FileAccess.file_exists("res://" + json_path):
		_start_game_with_file(global_json)
	else:
		# Prepare the song first
		_state_label.text = "Preparing song..."
		_state_label.visible = true
		_state_label.add_theme_color_override(&"font_color", Color(0.8, 0.8, 0.8, 0.8))

		# Run preparation in a thread to avoid blocking
		var prepared_path: String = SongSearch.prepare_song(song_id, file_path)
		if prepared_path != "":
			_start_game_with_file(prepared_path)
		else:
			_state_label.text = "Failed to prepare song"
			_state_label.add_theme_color_override(&"font_color", Color(0.9, 0.3, 0.3))


func _start_game_with_file(path: String) -> void:
	var song_data: Dictionary = SongLoader.load_song(path)
	if song_data.is_empty():
		push_warning("Failed to load song from " + path)
		return

	_game_engine.load_song(song_data)

	var title: String = song_data.get("meta", {}).get("title", "Unknown") as String
	print("Loaded song: " + title)

	# Hide song list, show game
	if _song_list != null:
		_song_list.visible = false

	_in_game = true
	_keyboard.visible = true
	_note_renderer.visible = true
	_state_label.visible = true
	_update_state_label(GameEngine.State.READY)


func _on_device_connected(device_name: String) -> void:
	_status_label.text = "Connected: " + device_name
	_status_label.add_theme_color_override(&"font_color", Color(0.4, 0.9, 0.5))


func _on_device_disconnected() -> void:
	_status_label.text = "No MIDI device"
	_status_label.add_theme_color_override(&"font_color", Color(0.6, 0.6, 0.6))


func _on_game_state_changed(state: int) -> void:
	_update_state_label(state as GameEngine.State)


func _update_state_label(state: GameEngine.State) -> void:
	match state:
		GameEngine.State.READY:
			_state_label.text = "Press any key to start"
			_state_label.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, 0.7))
		GameEngine.State.PLAYING:
			_state_label.text = ""
			_state_label.visible = false
		GameEngine.State.COMPLETE:
			_state_label.text = "Song Complete! (ESC for song list)"
			_state_label.visible = true
			_state_label.add_theme_color_override(&"font_color", Color(0.4, 0.95, 0.5, 0.95))


func _get_arg(flag: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == flag and i + 1 < args.size():
			return args[i + 1]
	return ""
