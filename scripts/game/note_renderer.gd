class_name NoteRenderer
extends Node2D
## Draws all falling note blocks using a single _draw() call.
## Driven by GameEngine — reads song_time, song data, and cleared notes from it.

const RIGHT_HAND: int = 0
const LEFT_HAND: int = 1

const RIGHT_HAND_COLOR := Color(0.2, 0.75, 0.35, 0.85)
const LEFT_HAND_COLOR := Color(0.25, 0.45, 0.85, 0.85)
const CLEARED_FLASH_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const WRONG_FLASH_COLOR := Color(0.9, 0.15, 0.15, 0.9)
const HIT_LINE_COLOR := Color(1.0, 1.0, 1.0, 0.5)
const HIT_LINE_HEIGHT: float = 3.0
const FINGER_COLOR := Color(1.0, 1.0, 1.0, 0.95)
const FINGER_FONT_SIZE: int = 22

## Pixels per second of song time — controls how fast notes scroll.
const PIXELS_PER_SECOND: float = 400.0
## How far above the viewport to pre-draw notes.
const OVERDRAW_MARGIN: float = 200.0
## How long visual feedback lasts (seconds).
const FLASH_DURATION: float = 0.25
## Gap in pixels between consecutive notes so same-pitch notes are visually distinct.
const NOTE_GAP: float = 4.0

var _hit_line_y: float
var _keyboard: PianoKeyboard
var _game_engine: GameEngine
var _font: Font

## Flash state for cleared notes: note_index -> time_remaining
var _clear_flashes: Dictionary = {}
## Flash state for wrong notes: time remaining
var _wrong_flash_timer: float = 0.0


func setup(keyboard: PianoKeyboard, game_engine: GameEngine) -> void:
	_keyboard = keyboard
	_game_engine = game_engine
	_hit_line_y = keyboard.get_top_y() - 10.0
	_font = ThemeDB.fallback_font
	Events.note_cleared.connect(_on_note_cleared)
	Events.wrong_note_played.connect(_on_wrong_note)


func _process(delta: float) -> void:
	# Tick down flash timers
	var to_remove: Array[int] = []
	for note_index: int in _clear_flashes:
		_clear_flashes[note_index] -= delta
		if _clear_flashes[note_index] as float <= 0.0:
			to_remove.append(note_index)
	for idx: int in to_remove:
		_clear_flashes.erase(idx)

	if _wrong_flash_timer > 0.0:
		_wrong_flash_timer -= delta

	queue_redraw()


func _draw() -> void:
	if _keyboard == null or _game_engine == null:
		return

	# Draw hit line
	var viewport_w: float = get_viewport_rect().size.x
	draw_rect(
		Rect2(0.0, _hit_line_y - HIT_LINE_HEIGHT / 2.0, viewport_w, HIT_LINE_HEIGHT),
		HIT_LINE_COLOR,
	)

	var song_notes: Array[Array] = _game_engine.get_song_notes()
	var spb: float = _game_engine.get_seconds_per_beat()
	var current_time: float = _game_engine.song_time

	for i: int in range(song_notes.size()):
		# Skip fully cleared notes (unless still flashing)
		if _game_engine.cleared_notes.has(i) and not _clear_flashes.has(i):
			continue

		var note: Array = song_notes[i]
		var midi_pitch: int = note[0] as int
		var start_beat: float = note[1] as float
		var duration_beats: float = note[2] as float
		var hand: int = note[3] as int

		var start_time: float = start_beat * spb
		var duration_time: float = duration_beats * spb

		# Note bottom edge Y = hit_line_y when note_time == song_time
		var note_bottom_y: float = _hit_line_y - (start_time - current_time) * PIXELS_PER_SECOND
		var note_height: float = duration_time * PIXELS_PER_SECOND - NOTE_GAP
		var note_top_y: float = note_bottom_y - note_height

		# Cull notes that are fully off-screen
		var viewport_h: float = get_viewport_rect().size.y
		if note_bottom_y < -OVERDRAW_MARGIN or note_top_y > viewport_h + OVERDRAW_MARGIN:
			continue

		var key_rect: Rect2 = _keyboard.get_key_rect(midi_pitch)
		if key_rect.size.x == 0.0:
			continue

		# Determine color
		var color: Color
		if _clear_flashes.has(i):
			color = CLEARED_FLASH_COLOR
		elif _wrong_flash_timer > 0.0 and _is_at_hit_line(start_time, current_time):
			color = WRONG_FLASH_COLOR
		else:
			color = RIGHT_HAND_COLOR if hand == RIGHT_HAND else LEFT_HAND_COLOR

		var block_rect := Rect2(
			key_rect.position.x + 2.0,
			note_top_y,
			key_rect.size.x - 4.0,
			note_height,
		)
		draw_rect(block_rect, color)
		draw_rect(block_rect, Color(1.0, 1.0, 1.0, 0.15), false, 1.0)

		# Draw finger number if available
		var finger: int = note[4] as int if note.size() > 4 else 0
		if finger > 0 and note_height >= FINGER_FONT_SIZE:
			var finger_str: String = str(finger)
			var text_size: Vector2 = _font.get_string_size(
				finger_str, HORIZONTAL_ALIGNMENT_CENTER, -1, FINGER_FONT_SIZE,
			)
			var text_x: float = block_rect.position.x + (block_rect.size.x - text_size.x) / 2.0
			var text_y: float = block_rect.position.y + block_rect.size.y - (block_rect.size.y - text_size.y) / 2.0
			draw_string(
				_font, Vector2(text_x, text_y), finger_str,
				HORIZONTAL_ALIGNMENT_CENTER, -1, FINGER_FONT_SIZE, FINGER_COLOR,
			)


func _is_at_hit_line(note_start_time: float, current_time: float) -> bool:
	return absf(note_start_time - current_time) < 0.01


func _on_note_cleared(pitch: int) -> void:
	# Find the note index for this pitch that was just cleared
	var song_notes: Array[Array] = _game_engine.get_song_notes()
	for i: int in range(song_notes.size()):
		if _game_engine.cleared_notes.has(i) and not _clear_flashes.has(i):
			if song_notes[i][0] as int == pitch:
				_clear_flashes[i] = FLASH_DURATION
				break


func _on_wrong_note() -> void:
	_wrong_flash_timer = FLASH_DURATION
