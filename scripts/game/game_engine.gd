class_name GameEngine
extends Node
## Core game loop — state machine, wait mode, hit detection.

enum State { READY, PLAYING, COMPLETE }

const RIGHT_HAND: int = 0
const BPM: float = 100.0
const SECONDS_PER_BEAT: float = 60.0 / BPM

## Twinkle Twinkle Little Star — right hand only.
## Format: [midi_pitch, start_beat, duration_beats, hand]
const SONG_NOTES: Array[Array] = [
	[60, 0.0, 1.0, 0],   # C4
	[60, 1.0, 1.0, 0],   # C4
	[67, 2.0, 1.0, 0],   # G4
	[67, 3.0, 1.0, 0],   # G4
	[69, 4.0, 1.0, 0],   # A4
	[69, 5.0, 1.0, 0],   # A4
	[67, 6.0, 2.0, 0],   # G4 (half)
	[65, 8.0, 1.0, 0],   # F4
	[65, 9.0, 1.0, 0],   # F4
	[64, 10.0, 1.0, 0],  # E4
	[64, 11.0, 1.0, 0],  # E4
	[62, 12.0, 1.0, 0],  # D4
	[62, 13.0, 1.0, 0],  # D4
	[60, 14.0, 2.0, 0],  # C4 (half)
]

## Song time in seconds — only advances when not waiting.
var song_time: float = 0.0
var state: State = State.READY
var cleared_notes: Dictionary = {}  # note_index -> true

## Each "event" is a group of notes at the same start_beat.
## Array of arrays: [[note_index, note_index, ...], ...]
var _events: Array[Array] = []
var _current_event_index: int = 0
## Pitches in the current event that still need to be hit.
var _pending_pitches: Dictionary = {}  # pitch -> note_index
var _waiting: bool = false


func _ready() -> void:
	_build_events()
	Events.midi_note_on.connect(_on_midi_note_on)


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return

	if _waiting:
		return

	song_time += delta

	# Check if the next event has reached the hit line
	if _current_event_index < _events.size():
		var event: Array = _events[_current_event_index]
		var first_note: Array = SONG_NOTES[event[0]]
		var event_time: float = (first_note[1] as float) * SECONDS_PER_BEAT
		if song_time >= event_time:
			song_time = event_time
			_start_waiting()


func start_playing() -> void:
	state = State.PLAYING
	song_time = -1.5  # Lead-in: 1.5s before first note
	_current_event_index = 0
	cleared_notes.clear()
	_waiting = false
	_pending_pitches.clear()
	Events.game_state_changed.emit(State.PLAYING)


func restart() -> void:
	start_playing()


func get_song_notes() -> Array[Array]:
	return SONG_NOTES


func get_seconds_per_beat() -> float:
	return SECONDS_PER_BEAT


func _build_events() -> void:
	## Group note indices by start_beat.
	var beat_map: Dictionary = {}  # start_beat -> [note_index, ...]
	for i: int in range(SONG_NOTES.size()):
		var beat: float = SONG_NOTES[i][1] as float
		if not beat_map.has(beat):
			beat_map[beat] = []
		beat_map[beat].append(i)

	# Sort by beat and build events array
	var beats: Array = beat_map.keys()
	beats.sort()
	for beat: float in beats:
		_events.append(beat_map[beat] as Array)


func _start_waiting() -> void:
	_waiting = true
	_pending_pitches.clear()
	var event: Array = _events[_current_event_index]
	for note_index: int in event:
		var pitch: int = SONG_NOTES[note_index][0] as int
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
		# Correct note
		var note_index: int = _pending_pitches[pitch] as int
		_pending_pitches.erase(pitch)
		cleared_notes[note_index] = true
		Events.note_cleared.emit(pitch)

		if _pending_pitches.is_empty():
			# All notes in this event cleared — advance
			_waiting = false
			_current_event_index += 1
			if _current_event_index >= _events.size():
				_complete_song()
	else:
		# Wrong note
		Events.wrong_note_played.emit()


func _complete_song() -> void:
	state = State.COMPLETE
	Events.song_completed.emit()
	Events.game_state_changed.emit(State.COMPLETE)
