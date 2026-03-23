extends GdUnitTestSuite
## Tests for GameEngine: state machine, scoring, hit detection, modes.

var _engine: GameEngine


func before_test() -> void:
	_engine = auto_free(GameEngine.new())
	add_child(_engine)
	_engine.load_song({
		"notes": [
			[60, 0.0, 1.0, 0, 1],
			[62, 1.0, 1.0, 0, 2],
			[64, 2.0, 1.0, 0, 3],
		],
		"tempo_bpm": 120.0,
	})


# --- State machine ---

func test_initial_state_is_ready() -> void:
	assert_int(_engine.state).is_equal(GameEngine.State.READY)


func test_note_on_starts_playing_from_ready() -> void:
	Events.midi_note_on.emit(60, 80)
	assert_int(_engine.state).is_equal(GameEngine.State.PLAYING)


func test_note_on_restarts_from_complete() -> void:
	_engine.state = GameEngine.State.COMPLETE
	Events.midi_note_on.emit(60, 80)
	assert_int(_engine.state).is_equal(GameEngine.State.PLAYING)


# --- Learn mode ---

func test_learn_mode_waits_at_first_note() -> void:
	_engine.play_mode = GameEngine.PlayMode.LEARN
	_engine.start_playing()
	# Advance past lead-in to first note
	_engine.song_time = 0.0
	_engine._process(0.016)
	assert_bool(_engine._waiting).is_true()


func test_correct_note_clears_in_learn_mode() -> void:
	_engine.play_mode = GameEngine.PlayMode.LEARN
	_engine.start_playing()
	_engine.song_time = 0.0
	_engine._process(0.016)
	Events.midi_note_on.emit(60, 80)
	assert_bool(_engine.cleared_notes.has(0)).is_true()
	assert_int(_engine.correct_count).is_equal(1)


func test_wrong_note_does_not_advance_in_learn_mode() -> void:
	_engine.play_mode = GameEngine.PlayMode.LEARN
	_engine.start_playing()
	_engine.song_time = 0.0
	_engine._process(0.016)
	Events.midi_note_on.emit(65, 80)
	assert_int(_engine._current_event_index).is_equal(0)
	assert_int(_engine.wrong_count).is_equal(1)


func test_all_notes_cleared_completes_learn_mode() -> void:
	_engine.play_mode = GameEngine.PlayMode.LEARN
	_engine.start_playing()
	# Fast-forward through lead-in and all notes
	for beat_time: float in [0.0, 0.5, 1.0]:
		_engine.song_time = beat_time - 0.001
		_engine._process(0.016)  # triggers waiting at beat_time
	# Now clear all 3 notes in sequence
	# First, go back and handle each one
	_engine.song_time = -1.5
	_engine.start_playing()  # Reset
	# Simulate a realistic playthrough
	_engine.song_time = -0.001
	_engine._process(0.016)  # song_time = 0.015, >= 0.0, wait for note 0
	assert_bool(_engine._waiting).is_true()
	Events.midi_note_on.emit(60, 80)  # Clear note 0
	assert_int(_engine._current_event_index).is_equal(1)
	_engine._process(0.5)  # song_time ~= 0.515, >= 0.5, wait for note 1
	Events.midi_note_on.emit(62, 80)  # Clear note 1
	assert_int(_engine._current_event_index).is_equal(2)
	_engine._process(0.5)  # song_time ~= 1.015, >= 1.0, wait for note 2
	Events.midi_note_on.emit(64, 80)  # Clear note 2
	assert_int(_engine.state).is_equal(GameEngine.State.COMPLETE)


# --- Scoring ---

func test_correct_note_increases_accuracy() -> void:
	_engine.start_playing()
	_engine.song_time = 0.0
	_engine._process(0.016)
	var before: float = _engine.accuracy
	Events.midi_note_on.emit(60, 80)
	assert_float(_engine.accuracy).is_greater(before)


func test_wrong_note_decreases_accuracy() -> void:
	_engine.start_playing()
	_engine.song_time = 0.0
	_engine._process(0.016)
	var before: float = _engine.accuracy
	Events.midi_note_on.emit(65, 80)
	assert_float(_engine.accuracy).is_less(before)


func test_scoring_asymmetry() -> void:
	assert_float(absf(GameEngine.SCORE_STEP_DOWN)).is_greater(GameEngine.SCORE_STEP_UP)


func test_streak_increments_on_correct() -> void:
	_engine.start_playing()
	_engine.song_time = 0.0
	_engine._process(0.016)
	Events.midi_note_on.emit(60, 80)
	assert_int(_engine.streak).is_equal(1)


func test_streak_resets_on_wrong() -> void:
	_engine.start_playing()
	_engine.song_time = 0.0
	_engine._process(0.016)
	Events.midi_note_on.emit(60, 80)
	assert_int(_engine.streak).is_equal(1)
	_engine._process(0.6)
	Events.midi_note_on.emit(65, 80)
	assert_int(_engine.streak).is_equal(0)
	assert_int(_engine.best_streak).is_equal(1)


# --- Stars ---

func test_three_stars_at_95_percent() -> void:
	_engine.accuracy = 0.95
	assert_int(_engine.get_stars()).is_equal(3)


func test_two_stars_at_80_percent() -> void:
	_engine.accuracy = 0.80
	assert_int(_engine.get_stars()).is_equal(2)


func test_one_star_below_80_percent() -> void:
	_engine.accuracy = 0.79
	assert_int(_engine.get_stars()).is_equal(1)


# --- Speed ---

func test_speed_clamp_minimum() -> void:
	_engine.set_speed(0.1)
	assert_float(_engine._speed_multiplier).is_equal(0.25)


func test_speed_clamp_maximum() -> void:
	_engine.set_speed(2.0)
	assert_float(_engine._speed_multiplier).is_equal(1.5)


func test_effective_spb_scales_with_speed() -> void:
	var base: float = _engine.get_effective_spb()
	_engine.set_speed(0.5)
	assert_float(_engine.get_effective_spb()).is_equal_approx(base * 2.0, 0.01)


# --- Hand filter ---

func test_hand_filter_right_only() -> void:
	_engine.load_song({
		"notes": [
			[60, 0.0, 1.0, 0, 1],
			[48, 0.0, 1.0, 1, 1],
			[62, 1.0, 1.0, 0, 2],
		],
		"tempo_bpm": 120.0,
	})
	_engine.set_hand_filter(0)
	assert_int(_engine._events.size()).is_equal(2)


func test_hand_filter_both() -> void:
	_engine.load_song({
		"notes": [
			[60, 0.0, 1.0, 0, 1],
			[48, 0.0, 1.0, 1, 1],
			[62, 1.0, 1.0, 0, 2],
		],
		"tempo_bpm": 120.0,
	})
	_engine.set_hand_filter(-1)
	# Beat 0 has 2 notes (chord), beat 1 has 1 note = 2 events
	assert_int(_engine._events.size()).is_equal(2)


# --- Play mode ---

func test_play_mode_auto_misses() -> void:
	_engine.play_mode = GameEngine.PlayMode.PLAY
	_engine.start_playing()
	_engine.song_time = 0.0 + GameEngine.OK_WINDOW + 0.1
	_engine._process(0.016)
	assert_int(_engine.miss_count).is_greater(0)
	assert_bool(_engine.missed_notes.has(0)).is_true()


# --- Fallback ---

func test_fallback_loads_twinkle() -> void:
	_engine.use_fallback()
	assert_int(_engine.get_song_notes().size()).is_equal(14)


# --- Start playing ---

func test_start_playing_resets_state() -> void:
	_engine.accuracy = 0.2
	_engine.correct_count = 10
	_engine.streak = 5
	_engine.start_playing()
	assert_float(_engine.accuracy).is_equal(0.5)
	assert_int(_engine.correct_count).is_equal(0)
	assert_int(_engine.streak).is_equal(0)
	assert_bool(_engine.cleared_notes.is_empty()).is_true()
