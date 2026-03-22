class_name PianoKeyboard
extends Node2D
## Draws an 88-key piano keyboard anchored to the bottom of the screen.

const FIRST_MIDI: int = 21  # A0
const LAST_MIDI: int = 108  # C8

const WHITE_KEY_COLOR := Color(0.92, 0.92, 0.92)
const WHITE_KEY_BORDER := Color(0.45, 0.45, 0.45)
const BLACK_KEY_COLOR := Color(0.12, 0.12, 0.12)
const BLACK_KEY_BORDER := Color(0.0, 0.0, 0.0)

## Highlight colors for pressed keys (right hand = green, left hand = blue).
const HIGHLIGHT_RIGHT := Color(0.2, 0.85, 0.4)
const HIGHLIGHT_LEFT := Color(0.3, 0.5, 0.95)
## Middle C — boundary between left and right hand coloring.
const MIDDLE_C: int = 60

## Height of the keyboard area in pixels.
const KEYBOARD_HEIGHT: float = 160.0
## Black keys are this fraction of white key height.
const BLACK_KEY_HEIGHT_RATIO: float = 0.62
## Black keys are this fraction of white key width.
const BLACK_KEY_WIDTH_RATIO: float = 0.6
## Border width for key outlines.
const BORDER_WIDTH: float = 2.0

## Black key offsets within an octave (relative to left edge of C).
## Real pianos have unevenly spaced black keys. These offsets are fractions
## of a white key width, measured from the left edge of C in that octave.
## note_in_octave -> offset from octave start (in white key widths)
const BLACK_KEY_OFFSETS: Dictionary = {
	1: 0.55,   # C# — between C and D
	3: 1.6,    # D# — between D and E
	6: 3.5,    # F# — between F and G
	8: 4.5,    # G# — between G and A
	10: 5.55,  # A# — between A and B
}

var _viewport_size: Vector2
var _white_key_width: float
var _key_rects: Dictionary = {}  # midi_pitch -> Rect2
var _pressed_keys: Dictionary = {}  # midi_pitch -> true
## Maps each white key midi pitch to its sequential index (0-based).
var _white_key_indices: Dictionary = {}  # midi_pitch -> int


func _ready() -> void:
	_viewport_size = get_viewport_rect().size
	_calculate_layout()
	Events.midi_note_on.connect(_on_midi_note_on)
	Events.midi_note_off.connect(_on_midi_note_off)


func _draw() -> void:
	var keyboard_top: float = _viewport_size.y - KEYBOARD_HEIGHT

	# Draw white keys first
	for midi: int in range(FIRST_MIDI, LAST_MIDI + 1):
		if _is_black_key(midi):
			continue
		var rect: Rect2 = _key_rects[midi]
		var fill: Color = _get_key_color(midi, false)
		draw_rect(rect, fill)

	# Draw dividing lines between white keys
	for midi: int in range(FIRST_MIDI, LAST_MIDI + 1):
		if _is_black_key(midi):
			continue
		var rect: Rect2 = _key_rects[midi]
		# Right edge divider
		draw_line(
			Vector2(rect.position.x + rect.size.x, keyboard_top),
			Vector2(rect.position.x + rect.size.x, keyboard_top + KEYBOARD_HEIGHT),
			WHITE_KEY_BORDER,
			BORDER_WIDTH,
		)

	# Top edge of keyboard
	draw_line(
		Vector2(0.0, keyboard_top),
		Vector2(_viewport_size.x, keyboard_top),
		WHITE_KEY_BORDER,
		BORDER_WIDTH,
	)

	# Draw black keys on top
	for midi: int in range(FIRST_MIDI, LAST_MIDI + 1):
		if not _is_black_key(midi):
			continue
		if not _key_rects.has(midi):
			continue
		var rect: Rect2 = _key_rects[midi]
		var fill: Color = _get_key_color(midi, true)
		draw_rect(rect, fill)
		draw_rect(rect, BLACK_KEY_BORDER, false, BORDER_WIDTH)


func get_key_rect(midi_pitch: int) -> Rect2:
	if _key_rects.has(midi_pitch):
		return _key_rects[midi_pitch]
	return Rect2()


func get_top_y() -> float:
	return _viewport_size.y - KEYBOARD_HEIGHT


func _calculate_layout() -> void:
	var keyboard_top: float = _viewport_size.y - KEYBOARD_HEIGHT

	# Count and index white keys
	var white_index: int = 0
	for midi: int in range(FIRST_MIDI, LAST_MIDI + 1):
		if not _is_black_key(midi):
			_white_key_indices[midi] = white_index
			white_index += 1
	var white_count: int = white_index

	_white_key_width = _viewport_size.x / float(white_count)

	# Position white keys
	for midi: int in range(FIRST_MIDI, LAST_MIDI + 1):
		if not _is_black_key(midi):
			var idx: int = _white_key_indices[midi] as int
			var x: float = idx * _white_key_width
			_key_rects[midi] = Rect2(x, keyboard_top, _white_key_width, KEYBOARD_HEIGHT)

	# Position black keys using real piano offsets
	for midi: int in range(FIRST_MIDI, LAST_MIDI + 1):
		if not _is_black_key(midi):
			continue
		var note_in_octave: int = midi % 12
		if not BLACK_KEY_OFFSETS.has(note_in_octave):
			continue

		# Find the C of this octave
		var octave_c: int = midi - note_in_octave
		# Find the white key index of that C (or the first white key in range)
		var ref_midi: int = octave_c
		if ref_midi < FIRST_MIDI:
			# For A0/B0 octave, offset from A0 instead
			continue
		if not _white_key_indices.has(ref_midi):
			continue

		var c_white_index: int = _white_key_indices[ref_midi] as int
		var offset: float = BLACK_KEY_OFFSETS[note_in_octave] as float
		var black_w: float = _white_key_width * BLACK_KEY_WIDTH_RATIO
		var black_h: float = KEYBOARD_HEIGHT * BLACK_KEY_HEIGHT_RATIO
		var center_x: float = (c_white_index as float + offset) * _white_key_width

		_key_rects[midi] = Rect2(
			center_x - black_w / 2.0,
			keyboard_top,
			black_w,
			black_h,
		)

	# Handle A#0 (MIDI 22) — the one black key whose C (C0=12) is below our range
	if not _key_rects.has(22) and _white_key_indices.has(21):
		# A0 is white index 0, B0 is white index 1. A#0 sits between them.
		var black_w: float = _white_key_width * BLACK_KEY_WIDTH_RATIO
		var black_h: float = KEYBOARD_HEIGHT * BLACK_KEY_HEIGHT_RATIO
		var a0_idx: int = _white_key_indices[21] as int
		var center_x: float = (a0_idx as float + 0.55) * _white_key_width
		_key_rects[22] = Rect2(
			center_x - black_w / 2.0,
			keyboard_top,
			black_w,
			black_h,
		)


func _get_key_color(midi: int, is_black: bool) -> Color:
	if _pressed_keys.has(midi):
		return HIGHLIGHT_RIGHT if midi >= MIDDLE_C else HIGHLIGHT_LEFT
	return BLACK_KEY_COLOR if is_black else WHITE_KEY_COLOR


func _on_midi_note_on(pitch: int, _velocity: int) -> void:
	_pressed_keys[pitch] = true
	queue_redraw()


func _on_midi_note_off(pitch: int) -> void:
	_pressed_keys.erase(pitch)
	queue_redraw()


static func _is_black_key(midi_pitch: int) -> bool:
	var note: int = midi_pitch % 12
	return note in [1, 3, 6, 8, 10]
