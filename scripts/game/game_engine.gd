class_name GameEngine
extends Node
## Core game loop — state machine, wait mode, hit detection.
## Accepts song data from SongLoader or uses hardcoded fallback.

enum State { READY, PLAYING, COMPLETE }

const RIGHT_HAND: int = 0
const DEFAULT_BPM: float = 100.0

## Hardcoded fallback: Twinkle Twinkle Little Star, right hand only.
## Format: [midi_pitch, start_beat, duration_beats, hand, finger]
const FALLBACK_NOTES: Array[Array] = [
	[60, 0.0, 1.0, 0, 1],
	[60, 1.0, 1.0, 0, 1],
	[67, 2.0, 1.0, 0, 5],
	[67, 3.0, 1.0, 0, 5],
	[69, 4.0, 1.0, 0, 5],
	[69, 5.0, 1.0, 0, 5],
	[67, 6.0, 2.0, 0, 5],
	[65, 8.0, 1.0, 0, 4],
	[65, 9.0, 1.0, 0, 4],
	[64, 10.0, 1.0, 0, 3],
	[64, 11.0, 1.0, 0, 3],
	[62, 12.0, 1.0, 0, 2],
	[62, 13.0, 1.0, 0, 2],
	[60, 14.0, 2.0, 0, 1],
]

var _song_notes: Array[Array] = []
var _bpm: float = DEFAULT_BPM
var _seconds_per_beat: float = 60.0 / DEFAULT_BPM

## Song time in seconds — only advances when not waiting.
var song_time: float = 0.0
var state: State = State.READY
var cleared_notes: Dictionary = {}  # note_index -> true

## Each "event" is a group of notes at the same start_beat.
var _events: Array[Array] = []
var _current_event_index: int = 0
var _pending_pitches: Dictionary = {}  # pitch -> note_index
var _waiting: bool = false


func _ready() -> void:
	Events.midi_note_on.connect(_on_midi_note_on)


func load_song(song_data: Dictionary) -> void:
	"""Load song data from SongLoader. Call before the game starts."""
	_song_notes = song_data.get("notes", FALLBACK_NOTES) as Array[Array]
	_bpm = song_data.get("tempo_bpm", DEFAULT_BPM) as float
	_seconds_per_beat = 60.0 / _bpm
	_build_events()


func use_fallback() -> void:
	"""Use the hardcoded Twinkle Twinkle as fallback."""
	_song_notes = FALLBACK_NOTES
	_bpm = DEFAULT_BPM
	_seconds_per_beat = 60.0 / _bpm
	_build_events()


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return

	if _waiting:
		return

	song_time += delta

	if _current_event_index < _events.size():
		var event: Array = _events[_current_event_index]
		var first_note: Array = _song_notes[event[0]]
		var event_time: float = (first_note[1] as float) * _seconds_per_beat
		if song_time >= event_time:
			song_time = event_time
			_start_waiting()


func start_playing() -> void:
	if _song_notes.is_empty():
		use_fallback()
	state = State.PLAYING
	song_time = -1.5
	_current_event_index = 0
	cleared_notes.clear()
	_waiting = false
	_pending_pitches.clear()
	Events.game_state_changed.emit(State.PLAYING)


func restart() -> void:
	start_playing()


func get_song_notes() -> Array[Array]:
	return _song_notes


func get_seconds_per_beat() -> float:
	return _seconds_per_beat


func _build_events() -> void:
	_events.clear()
	var beat_map: Dictionary = {}
	for i: int in range(_song_notes.size()):
		var beat: float = _song_notes[i][1] as float
		if not beat_map.has(beat):
			beat_map[beat] = []
		beat_map[beat].append(i)

	var beats: Array = beat_map.keys()
	beats.sort()
	for beat: float in beats:
		_events.append(beat_map[beat] as Array)


func _start_waiting() -> void:
	_waiting = true
	_pending_pitches.clear()
	var event: Array = _events[_current_event_index]
	for note_index: int in event:
		var pitch: int = _song_notes[note_index][0] as int
		_pending_pitches[pitch] = note_index


func _on_midi_note_on(pitch: int, _velocity: int) -> void:
	if state == State.READY:
		start_playing()
		return

	if state == State.COMPLETE:
		restart()
		return

	if not _waiting:
		return

	if _pending_pitches.has(pitch):
		var note_index: int = _pending_pitches[pitch] as int
		_pending_pitches.erase(pitch)
		cleared_notes[note_index] = true
		Events.note_cleared.emit(pitch)

		if _pending_pitches.is_empty():
			_waiting = false
			_current_event_index += 1
			if _current_event_index >= _events.size():
				_complete_song()
	else:
		Events.wrong_note_played.emit()


func _complete_song() -> void:
	state = State.COMPLETE
	Events.song_completed.emit()
	Events.game_state_changed.emit(State.COMPLETE)
