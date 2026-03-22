class_name PianoKeyboard
extends Node2D
## Draws an 88-key piano keyboard anchored to the bottom of the screen.

const FIRST_MIDI: int = 21  # A0
const LAST_MIDI: int = 108  # C8
const TOTAL_KEYS: int = 88

const WHITE_KEY_COLOR := Color(0.92, 0.92, 0.92)
const WHITE_KEY_OUTLINE := Color(0.3, 0.3, 0.3)
const BLACK_KEY_COLOR := Color(0.12, 0.12, 0.12)
const BLACK_KEY_OUTLINE := Color(0.0, 0.0, 0.0)

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
const BLACK_KEY_WIDTH_RATIO: float = 0.58

var _viewport_size: Vector2
var _white_key_width: float
var _white_key_positions: Array[float] = []  # x position of each white key
var _key_rects: Dictionary = {}  # midi_pitch -> Rect2
var _pressed_keys: Dictionary = {}  # midi_pitch -> true


func _ready() -> void:
	_viewport_size = get_viewport_rect().size
	_calculate_layout()
	Events.midi_note_on.connect(_on_midi_note_on)
	Events.midi_note_off.connect(_on_midi_note_off)


func _draw() -> void:
	# Draw white keys first
	for midi: int in range(FIRST_MIDI, LAST_MIDI + 1):
		if not _is_black_key(midi):
			var rect: Rect2 = _key_rects[midi]
			var color: Color = _get_key_color(midi, false)
			draw_rect(rect, color)
			draw_rect(rect, WHITE_KEY_OUTLINE, false, 1.0)

	# Draw black keys on top
	for midi: int in range(FIRST_MIDI, LAST_MIDI + 1):
		if _is_black_key(midi):
			var rect: Rect2 = _key_rects[midi]
			var color: Color = _get_key_color(midi, true)
			draw_rect(rect, color)
			draw_rect(rect, BLACK_KEY_OUTLINE, false, 1.0)


func get_key_rect(midi_pitch: int) -> Rect2:
	if _key_rects.has(midi_pitch):
		return _key_rects[midi_pitch]
	return Rect2()


func get_top_y() -> float:
	return _viewport_size.y - KEYBOARD_HEIGHT


func _calculate_layout() -> void:
	# Count white keys
	var white_count: int = 0
	for midi: int in range(FIRST_MIDI, LAST_MIDI + 1):
		if not _is_black_key(midi):
			white_count += 1

	_white_key_width = _viewport_size.x / float(white_count)
	var keyboard_top: float = _viewport_size.y - KEYBOARD_HEIGHT

	# Position white keys
	var white_index: int = 0
	for midi: int in range(FIRST_MIDI, LAST_MIDI + 1):
		if not _is_black_key(midi):
			var x: float = white_index * _white_key_width
			_key_rects[midi] = Rect2(x, keyboard_top, _white_key_width, KEYBOARD_HEIGHT)
			_white_key_positions.append(x)
			white_index += 1

	# Position black keys — centered between their neighboring white keys
	for midi: int in range(FIRST_MIDI, LAST_MIDI + 1):
		if _is_black_key(midi):
			var left_white: int = midi - 1
			var right_white: int = midi + 1
			if _key_rects.has(left_white) and _key_rects.has(right_white):
				var left_rect: Rect2 = _key_rects[left_white]
				var right_rect: Rect2 = _key_rects[right_white]
				var black_w: float = _white_key_width * BLACK_KEY_WIDTH_RATIO
				var center_x: float = (left_rect.position.x + left_rect.size.x + right_rect.position.x) / 2.0
				var black_h: float = KEYBOARD_HEIGHT * BLACK_KEY_HEIGHT_RATIO
				_key_rects[midi] = Rect2(
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
	# C=0, C#=1, D=2, D#=3, E=4, F=5, F#=6, G=7, G#=8, A=9, A#=10, B=11
	return note in [1, 3, 6, 8, 10]
