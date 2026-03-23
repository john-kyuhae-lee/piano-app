class_name GameEngine
extends Node
## Core game loop — state machine, three play modes, scoring, hit detection.

enum State { READY, PLAYING, COMPLETE }
enum PlayMode { LEARN, PLAY, PERFORM }
enum HitGrade { PERFECT, GOOD, OK, MISS }

const RIGHT_HAND: int = 0
const DEFAULT_BPM: float = 100.0

## Timing windows in seconds
const PERFECT_WINDOW: float = 0.05
const GOOD_WINDOW: float = 0.15
const OK_WINDOW: float = 0.3

## Scoring (asymmetric — PianoBooster research)
const SCORE_STEP_UP: float = 0.01
const SCORE_STEP_DOWN: float = -0.05

## Hardcoded fallback: Twinkle Twinkle Little Star
const FALLBACK_NOTES: Array[Array] = [
	[60, 0.0, 1.0, 0, 1], [60, 1.0, 1.0, 0, 1],
	[67, 2.0, 1.0, 0, 5], [67, 3.0, 1.0, 0, 5],
	[69, 4.0, 1.0, 0, 5], [69, 5.0, 1.0, 0, 5],
	[67, 6.0, 2.0, 0, 5],
	[65, 8.0, 1.0, 0, 4], [65, 9.0, 1.0, 0, 4],
	[64, 10.0, 1.0, 0, 3], [64, 11.0, 1.0, 0, 3],
	[62, 12.0, 1.0, 0, 2], [62, 13.0, 1.0, 0, 2],
	[60, 14.0, 2.0, 0, 1],
]

var _song_notes: Array[Array] = []
var _bpm: float = DEFAULT_BPM
var _seconds_per_beat: float = 60.0 / DEFAULT_BPM
var _speed_multiplier: float = 1.0

## Public state
var song_time: float = 0.0
var state: State = State.READY
var play_mode: PlayMode = PlayMode.LEARN
var cleared_notes: Dictionary = {}  # note_index -> true
var missed_notes: Dictionary = {}  # note_index -> true (Play/Perform only)
var accuracy: float = 0.5  # Running score 0.0–1.0
var correct_count: int = 0
var wrong_count: int = 0
var miss_count: int = 0
var streak: int = 0
var best_streak: int = 0

## Internal
var _events: Array[Array] = []
var _current_event_index: int = 0
var _pending_pitches: Dictionary = {}
var _waiting: bool = false
var _hand_filter: int = -1  # -1 = both, 0 = right only, 1 = left only


func _ready() -> void:
	Events.midi_note_on.connect(_on_midi_note_on)


func load_song(song_data: Dictionary) -> void:
	var raw_notes: Array = song_data.get("notes", []) as Array
	_song_notes.clear()
	if raw_notes.is_empty():
		_song_notes = FALLBACK_NOTES.duplicate()
	else:
		for note: Variant in raw_notes:
			_song_notes.append(note as Array)
	_bpm = song_data.get("tempo_bpm", DEFAULT_BPM) as float
	_seconds_per_beat = 60.0 / _bpm
	_build_events()


func use_fallback() -> void:
	_song_notes = FALLBACK_NOTES
	_bpm = DEFAULT_BPM
	_seconds_per_beat = 60.0 / _bpm
	_build_events()


func set_speed(multiplier: float) -> void:
	_speed_multiplier = clampf(multiplier, 0.25, 1.5)


func set_hand_filter(hand: int) -> void:
	## -1 = both, 0 = right only, 1 = left only
	_hand_filter = hand
	_build_events()


func get_effective_spb() -> float:
	## Seconds per beat adjusted for speed
	return _seconds_per_beat / _speed_multiplier


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return

	if play_mode == PlayMode.LEARN:
		_process_learn_mode(delta)
	else:
		_process_timed_mode(delta)


func start_playing() -> void:
	if _song_notes.is_empty():
		use_fallback()
	state = State.PLAYING
	song_time = -1.5 / _speed_multiplier
	_current_event_index = 0
	cleared_notes.clear()
	missed_notes.clear()
	accuracy = 0.5
	correct_count = 0
	wrong_count = 0
	miss_count = 0
	streak = 0
	best_streak = 0
	_waiting = false
	_pending_pitches.clear()
	Events.game_state_changed.emit(State.PLAYING)


func restart() -> void:
	start_playing()


func get_song_notes() -> Array[Array]:
	return _song_notes


func get_seconds_per_beat() -> float:
	return get_effective_spb()


func get_stars() -> int:
	if accuracy >= 0.95:
		return 3
	elif accuracy >= 0.80:
		return 2
	else:
		return 1


## --- Learn Mode (wait mode) ---

func _process_learn_mode(delta: float) -> void:
	if _waiting:
		return
	song_time += delta
	if _current_event_index < _events.size():
		var event: Array = _events[_current_event_index]
		var first_note: Array = _song_notes[event[0]]
		var event_time: float = (first_note[1] as float) * get_effective_spb()
		if song_time >= event_time:
			song_time = event_time
			_start_waiting()


## --- Play / Perform Mode (timed) ---

func _process_timed_mode(delta: float) -> void:
	song_time += delta

	# Check if current event should be auto-missed (timed out)
	while _current_event_index < _events.size():
		var event: Array = _events[_current_event_index]
		var first_note: Array = _song_notes[event[0]]
		var event_time: float = (first_note[1] as float) * get_effective_spb()
		var time_past: float = song_time - event_time

		if time_past > OK_WINDOW:
			# Missed — auto-clear in Play/Perform mode
			for note_index: int in event:
				if not cleared_notes.has(note_index):
					missed_notes[note_index] = true
					miss_count += 1
					accuracy = clampf(accuracy + SCORE_STEP_DOWN, 0.0, 1.0)
					streak = 0
			_current_event_index += 1
			_waiting = false
			_pending_pitches.clear()
		else:
			# Current event is still in the timing window
			if not _waiting and time_past >= -OK_WINDOW:
				_start_waiting()
			break

	# Check song complete
	if _current_event_index >= _events.size():
		# Wait for last note to scroll past
		var last_note: Array = _song_notes[_events[_events.size() - 1][0]]
		var last_time: float = (last_note[1] as float) * get_effective_spb()
		if song_time > last_time + 1.0:
			_complete_song()


## --- Common ---

func _build_events() -> void:
	_events.clear()
	var beat_map: Dictionary = {}
	for i: int in range(_song_notes.size()):
		# Apply hand filter
		if _hand_filter >= 0:
			var note_hand: int = _song_notes[i][3] as int
			if note_hand != _hand_filter:
				continue
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
	if _current_event_index >= _events.size():
		return
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
		if play_mode != PlayMode.LEARN:
			# In timed modes, wrong notes outside waiting still count
			wrong_count += 1
			accuracy = clampf(accuracy + SCORE_STEP_DOWN, 0.0, 1.0)
			streak = 0
			Events.wrong_note_played.emit()
		return

	if _pending_pitches.has(pitch):
		var note_index: int = _pending_pitches[pitch] as int
		_pending_pitches.erase(pitch)
		cleared_notes[note_index] = true
		correct_count += 1
		accuracy = clampf(accuracy + SCORE_STEP_UP, 0.0, 1.0)
		streak += 1
		best_streak = maxi(best_streak, streak)
		Events.note_cleared.emit(pitch)

		if _pending_pitches.is_empty():
			_waiting = false
			_current_event_index += 1
			if play_mode == PlayMode.LEARN:
				if _current_event_index >= _events.size():
					_complete_song()
	else:
		wrong_count += 1
		accuracy = clampf(accuracy + SCORE_STEP_DOWN, 0.0, 1.0)
		streak = 0
		Events.wrong_note_played.emit()


func _complete_song() -> void:
	state = State.COMPLETE
	Events.song_completed.emit()
	Events.game_state_changed.emit(State.COMPLETE)
