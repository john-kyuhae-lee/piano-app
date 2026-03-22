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
const MISSED_COLOR := Color(0.4, 0.4, 0.4, 0.3)
const HIT_LINE_COLOR := Color(1.0, 1.0, 1.0, 0.5)
const HIT_LINE_HEIGHT: float = 3.0
const BEAT_LINE_COLOR := Color(1.0, 1.0, 1.0, 0.08)
const FINGER_COLOR := Color(1.0, 1.0, 1.0, 0.95)
const FINGER_FONT_SIZE: int = 22
## Glow effect — additive-blend larger rect behind active notes (Neothesia approach)
const GLOW_COLOR_RIGHT := Color(0.2, 0.75, 0.35, 0.15)
const GLOW_COLOR_LEFT := Color(0.25, 0.45, 0.85, 0.15)
const GLOW_EXPAND: float = 6.0

const PIXELS_PER_SECOND: float = 400.0
const OVERDRAW_MARGIN: float = 200.0
const FLASH_DURATION: float = 0.25
const NOTE_GAP: float = 4.0

var _hit_line_y: float
var _keyboard: PianoKeyboard
var _game_engine: GameEngine
var _font: Font

var _clear_flashes: Dictionary = {}
var _wrong_flash_timer: float = 0.0


func setup(keyboard: PianoKeyboard, game_engine: GameEngine) -> void:
	_keyboard = keyboard
	_game_engine = game_engine
	_hit_line_y = keyboard.get_top_y() - 10.0
	_font = ThemeDB.fallback_font
	Events.note_cleared.connect(_on_note_cleared)
	Events.wrong_note_played.connect(_on_wrong_note)


func _process(delta: float) -> void:
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

	var viewport_w: float = get_viewport_rect().size.x
	var viewport_h: float = get_viewport_rect().size.y
	var song_notes: Array[Array] = _game_engine.get_song_notes()
	var spb: float = _game_engine.get_seconds_per_beat()
	var current_time: float = _game_engine.song_time

	# Draw beat lines (subtle visual metronome — Dalcroze)
	_draw_beat_lines(spb, current_time, viewport_w, viewport_h)

	# Draw hit line
	draw_rect(
		Rect2(0.0, _hit_line_y - HIT_LINE_HEIGHT / 2.0, viewport_w, HIT_LINE_HEIGHT),
		HIT_LINE_COLOR,
	)

	# Draw notes
	for i: int in range(song_notes.size()):
		# Skip fully cleared notes (unless still flashing)
		var is_cleared: bool = _game_engine.cleared_notes.has(i)
		var is_missed: bool = _game_engine.missed_notes.has(i)
		var is_flashing: bool = _clear_flashes.has(i)

		if is_cleared and not is_flashing:
			continue
		if is_missed:
			continue  # Missed notes disappear in timed modes

		var note: Array = song_notes[i]
		var midi_pitch: int = note[0] as int
		var start_beat: float = note[1] as float
		var duration_beats: float = note[2] as float
		var hand: int = note[3] as int

		var start_time: float = start_beat * spb
		var duration_time: float = duration_beats * spb

		var note_bottom_y: float = _hit_line_y - (start_time - current_time) * PIXELS_PER_SECOND
		var note_height: float = duration_time * PIXELS_PER_SECOND - NOTE_GAP
		var note_top_y: float = note_bottom_y - note_height

		if note_bottom_y < -OVERDRAW_MARGIN or note_top_y > viewport_h + OVERDRAW_MARGIN:
			continue

		var key_rect: Rect2 = _keyboard.get_key_rect(midi_pitch)
		if key_rect.size.x == 0.0:
			continue

		# Color
		var color: Color
		if is_flashing:
			color = CLEARED_FLASH_COLOR
		elif _wrong_flash_timer > 0.0 and _is_near_hit_line(start_time, current_time):
			color = WRONG_FLASH_COLOR
		else:
			color = RIGHT_HAND_COLOR if hand == RIGHT_HAND else LEFT_HAND_COLOR

		var block_rect := Rect2(
			key_rect.position.x + 2.0,
			note_top_y,
			key_rect.size.x - 4.0,
			note_height,
		)

		# Glow effect (additive layer behind the block — Neothesia approach)
		if not is_flashing:
			var glow_color: Color = GLOW_COLOR_RIGHT if hand == RIGHT_HAND else GLOW_COLOR_LEFT
			var glow_rect := Rect2(
				block_rect.position.x - GLOW_EXPAND,
				block_rect.position.y - GLOW_EXPAND,
				block_rect.size.x + GLOW_EXPAND * 2.0,
				block_rect.size.y + GLOW_EXPAND * 2.0,
			)
			draw_rect(glow_rect, glow_color)

		draw_rect(block_rect, color)
		draw_rect(block_rect, Color(1.0, 1.0, 1.0, 0.15), false, 1.0)

		# Finger number
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


func _draw_beat_lines(spb: float, current_time: float, viewport_w: float, viewport_h: float) -> void:
	## Draw subtle horizontal lines at each beat for visual rhythm reference.
	if spb <= 0.0:
		return

	# Find the range of visible beats
	var top_time: float = current_time + viewport_h / PIXELS_PER_SECOND
	var bottom_time: float = current_time - 1.0

	var first_beat: int = int(bottom_time / spb)
	var last_beat: int = int(top_time / spb) + 1

	for beat: int in range(first_beat, last_beat + 1):
		var beat_time: float = float(beat) * spb
		var y: float = _hit_line_y - (beat_time - current_time) * PIXELS_PER_SECOND
		if y < 0.0 or y > _hit_line_y:
			continue
		# Stronger line every 4 beats (measure line)
		var alpha: float = 0.12 if beat % 4 == 0 else 0.05
		draw_line(
			Vector2(0.0, y), Vector2(viewport_w, y),
			Color(1.0, 1.0, 1.0, alpha), 1.0,
		)


func _is_near_hit_line(note_start_time: float, current_time: float) -> bool:
	return absf(note_start_time - current_time) < 0.3


func _on_note_cleared(pitch: int) -> void:
	var song_notes: Array[Array] = _game_engine.get_song_notes()
	for i: int in range(song_notes.size()):
		if _game_engine.cleared_notes.has(i) and not _clear_flashes.has(i):
			if song_notes[i][0] as int == pitch:
				_clear_flashes[i] = FLASH_DURATION
				break


func _on_wrong_note() -> void:
	_wrong_flash_timer = FLASH_DURATION
