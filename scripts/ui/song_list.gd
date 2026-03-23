class_name SongListUI
extends Control
## Song browser UI — search bar + scrollable list of songs.
## Emits song_selected when a song is chosen.

signal song_selected(song_data: Dictionary)

const CARD_HEIGHT: float = 80.0
const CARD_MARGIN: float = 8.0
const BG_COLOR := Color(0.08, 0.08, 0.1)
const CARD_COLOR := Color(0.14, 0.14, 0.18)
const CARD_HOVER_COLOR := Color(0.2, 0.2, 0.26)
const TITLE_COLOR := Color(0.95, 0.95, 0.95)
const SUBTITLE_COLOR := Color(0.6, 0.6, 0.65)
const STAR_COLOR := Color(1.0, 0.85, 0.2)
const DIFFICULTY_COLORS: Array[Color] = [
	Color(0.3, 0.85, 0.4),   # Easy (1-2)
	Color(0.3, 0.85, 0.4),   # Easy
	Color(0.9, 0.85, 0.2),   # Medium (3-4)
	Color(0.9, 0.85, 0.2),   # Medium
	Color(0.95, 0.6, 0.2),   # Hard (5-6)
	Color(0.95, 0.6, 0.2),   # Hard
	Color(0.9, 0.3, 0.3),    # Very Hard (7-8)
	Color(0.9, 0.3, 0.3),    # Very Hard
	Color(0.8, 0.2, 0.6),    # Expert (9-10)
	Color(0.8, 0.2, 0.6),    # Expert
]

var _songs: Array[Dictionary] = []
var _search_box: LineEdit
var _scroll: ScrollContainer
var _song_container: VBoxContainer
var _title_label: Label
var _loading_label: Label


func _ready() -> void:
	_build_ui()
	_load_songs.call_deferred()


func _build_ui() -> void:
	# Full screen
	set_anchors_preset(PRESET_FULL_RECT)

	# Background
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Title
	_title_label = Label.new()
	_title_label.text = "Piano Hero"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override(&"font_size", 42)
	_title_label.add_theme_color_override(&"font_color", TITLE_COLOR)
	_title_label.position = Vector2(0, 30)
	_title_label.size = Vector2(get_viewport_rect().size.x, 60)
	add_child(_title_label)

	# Search box
	_search_box = LineEdit.new()
	_search_box.placeholder_text = "Search songs..."
	_search_box.add_theme_font_size_override(&"font_size", 24)
	_search_box.position = Vector2(200, 110)
	_search_box.size = Vector2(get_viewport_rect().size.x - 400, 45)
	_search_box.text_changed.connect(_on_search_changed)
	add_child(_search_box)

	# Loading indicator
	_loading_label = Label.new()
	_loading_label.text = "Loading songs..."
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override(&"font_size", 20)
	_loading_label.add_theme_color_override(&"font_color", SUBTITLE_COLOR)
	_loading_label.position = Vector2(0, 300)
	_loading_label.size = Vector2(get_viewport_rect().size.x, 30)
	add_child(_loading_label)

	# Scroll container for song list
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(100, 175)
	_scroll.size = Vector2(
		get_viewport_rect().size.x - 200,
		get_viewport_rect().size.y - 195,
	)
	add_child(_scroll)

	_song_container = VBoxContainer.new()
	_song_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_song_container.add_theme_constant_override(&"separation", int(CARD_MARGIN))
	_scroll.add_child(_song_container)


func _load_songs() -> void:
	_loading_label.text = "Loading songs..."
	_loading_label.visible = true
	var thread := Thread.new()
	thread.start(_load_songs_thread)
	# Store thread ref to prevent GC
	set_meta(&"_load_thread", thread)


func _load_songs_thread() -> void:
	var songs: Array[Dictionary] = SongSearch.get_all_songs(200)
	_display_songs_deferred.call_deferred(songs)


func _display_songs_deferred(songs: Array[Dictionary]) -> void:
	_songs = songs
	_loading_label.visible = false
	_display_songs(_songs)
	# Clean up thread
	var thread: Thread = get_meta(&"_load_thread") as Thread
	if thread:
		thread.wait_to_finish()


func _on_search_changed(query: String) -> void:
	if query.length() < 2 and query.length() > 0:
		return
	_loading_label.text = "Searching..."
	_loading_label.visible = true
	var thread := Thread.new()
	thread.start(_search_thread.bind(query))
	set_meta(&"_search_thread", thread)


func _search_thread(query: String) -> void:
	var results: Array[Dictionary] = SongSearch.search(query, 50)
	_display_songs_deferred.call_deferred(results)


func _display_songs(songs: Array[Dictionary]) -> void:
	# Clear existing
	for child: Node in _song_container.get_children():
		child.queue_free()

	if songs.is_empty():
		var empty := Label.new()
		empty.text = "No songs found"
		empty.add_theme_font_size_override(&"font_size", 20)
		empty.add_theme_color_override(&"font_color", SUBTITLE_COLOR)
		_song_container.add_child(empty)
		return

	for song: Dictionary in songs:
		var card: Button = _create_song_card(song)
		_song_container.add_child(card)


func _create_song_card(song: Dictionary) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	card.flat = true
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT

	# Difficulty stars
	var diff: float = song.get("difficulty", 5.0) as float
	var star_count: int = clampi(int(diff / 2.0), 1, 5)
	var stars: String = "★".repeat(star_count) + "☆".repeat(5 - star_count)

	# Color based on difficulty
	var diff_idx: int = clampi(int(diff) - 1, 0, 9)
	var diff_color: Color = DIFFICULTY_COLORS[diff_idx]

	# Format duration
	var dur: float = song.get("duration_seconds", 0.0) as float
	var dur_str: String = "%d:%02d" % [int(dur) / 60, int(dur) % 60]

	var title: String = song.get("title", "Unknown") as String
	var composer: String = song.get("composer", "Unknown") as String
	var tempo: int = song.get("tempo_bpm", 120) as int

	card.text = "%s  %s — %s  (%d BPM, %s)" % [stars, title, composer, tempo, dur_str]
	card.add_theme_font_size_override(&"font_size", 20)
	card.add_theme_color_override(&"font_color", TITLE_COLOR)

	# Store song data on the card
	card.set_meta(&"song_data", song)
	card.pressed.connect(_on_card_pressed.bind(card))

	return card


func _on_card_pressed(card: Button) -> void:
	var song: Dictionary = card.get_meta(&"song_data") as Dictionary
	song_selected.emit(song)
