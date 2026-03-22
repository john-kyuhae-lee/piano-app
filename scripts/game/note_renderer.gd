class_name NoteRenderer
extends Node2D
## Draws all falling note blocks using a single _draw() call.

const RIGHT_HAND: int = 0
const LEFT_HAND: int = 1

const RIGHT_HAND_COLOR := Color(0.2, 0.75, 0.35, 0.85)
const LEFT_HAND_COLOR := Color(0.25, 0.45, 0.85, 0.85)
const HIT_LINE_COLOR := Color(1.0, 1.0, 1.0, 0.5)
const HIT_LINE_HEIGHT: float = 3.0

## Pixels per second of song time — controls how fast notes scroll.
const PIXELS_PER_SECOND: float = 400.0
## BPM for the hardcoded song.
const BPM: float = 120.0
## Seconds per beat.
const SECONDS_PER_BEAT: float = 60.0 / BPM
## How far above the viewport to pre-draw notes.
const OVERDRAW_MARGIN: float = 200.0

## Note format: [midi_pitch, start_beat, duration_beats, hand]
var _song_notes: Array = [
	# Right hand — C major ascending
	[60, 0.0, 1.0, RIGHT_HAND],
	[62, 1.0, 1.0, RIGHT_HAND],
	[64, 2.0, 1.0, RIGHT_HAND],
	[65, 3.0, 1.0, RIGHT_HAND],
	[67, 4.0, 1.0, RIGHT_HAND],
	[69, 5.0, 1.0, RIGHT_HAND],
	[71, 6.0, 1.0, RIGHT_HAND],
	[72, 7.0, 1.0, RIGHT_HAND],
	# Left hand — C major descending
	[48, 0.0, 1.0, LEFT_HAND],
	[47, 1.0, 1.0, LEFT_HAND],
	[45, 2.0, 1.0, LEFT_HAND],
	[43, 3.0, 1.0, LEFT_HAND],
	[41, 4.0, 1.0, LEFT_HAND],
	[40, 5.0, 1.0, LEFT_HAND],
	[38, 6.0, 1.0, LEFT_HAND],
	[36, 7.0, 1.0, LEFT_HAND],
]

var _song_time: float = 0.0
var _song_duration_seconds: float
var _hit_line_y: float
var _keyboard: PianoKeyboard


func setup(keyboard: PianoKeyboard) -> void:
	_keyboard = keyboard
	_hit_line_y = keyboard.get_top_y() - 10.0
	_song_duration_seconds = 8.0 * SECONDS_PER_BEAT + 1.0  # 8 beats + 1s gap


func _process(delta: float) -> void:
	_song_time += delta
	if _song_time >= _song_duration_seconds:
		_song_time = 0.0
	queue_redraw()


func _draw() -> void:
	if _keyboard == null:
		return

	# Draw hit line
	var viewport_w: float = get_viewport_rect().size.x
	draw_rect(
		Rect2(0.0, _hit_line_y - HIT_LINE_HEIGHT / 2.0, viewport_w, HIT_LINE_HEIGHT),
		HIT_LINE_COLOR,
	)

	# Draw notes
	for note: Array in _song_notes:
		var midi_pitch: int = note[0] as int
		var start_beat: float = note[1] as float
		var duration_beats: float = note[2] as float
		var hand: int = note[3] as int

		var start_time: float = start_beat * SECONDS_PER_BEAT
		var duration_time: float = duration_beats * SECONDS_PER_BEAT

		# Note bottom edge Y = hit_line_y when note_time == song_time
		var note_bottom_y: float = _hit_line_y - (start_time - _song_time) * PIXELS_PER_SECOND
		var note_height: float = duration_time * PIXELS_PER_SECOND
		var note_top_y: float = note_bottom_y - note_height

		# Cull notes that are fully off-screen
		var viewport_h: float = get_viewport_rect().size.y
		if note_bottom_y < -OVERDRAW_MARGIN or note_top_y > viewport_h + OVERDRAW_MARGIN:
			continue

		var key_rect: Rect2 = _keyboard.get_key_rect(midi_pitch)
		if key_rect.size.x == 0.0:
			continue

		var color: Color = RIGHT_HAND_COLOR if hand == RIGHT_HAND else LEFT_HAND_COLOR
		var block_rect := Rect2(
			key_rect.position.x + 2.0,
			note_top_y,
			key_rect.size.x - 4.0,
			note_height,
		)
		draw_rect(block_rect, color)
		# Subtle lighter border
		draw_rect(block_rect, Color(1.0, 1.0, 1.0, 0.15), false, 1.0)
