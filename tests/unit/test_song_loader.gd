extends GdUnitTestSuite
## Tests for SongLoader: JSON parsing, validation, error handling.


func test_load_valid_song() -> void:
	var path: String = ProjectSettings.globalize_path("res://tests/fixtures/test_song.json")
	var data: Dictionary = SongLoader.load_song(path)
	assert_dict(data).is_not_empty()
	assert_bool(data.has("notes")).is_true()
	assert_bool(data.has("meta")).is_true()
	assert_bool(data.has("tempo_bpm")).is_true()


func test_note_count() -> void:
	var path: String = ProjectSettings.globalize_path("res://tests/fixtures/test_song.json")
	var data: Dictionary = SongLoader.load_song(path)
	var notes: Array = data["notes"] as Array
	assert_int(notes.size()).is_equal(3)


func test_notes_sorted_by_beat() -> void:
	var path: String = ProjectSettings.globalize_path("res://tests/fixtures/test_song.json")
	var data: Dictionary = SongLoader.load_song(path)
	var notes: Array = data["notes"] as Array
	for i: int in range(notes.size() - 1):
		var beat_a: float = (notes[i] as Array)[1] as float
		var beat_b: float = (notes[i + 1] as Array)[1] as float
		assert_float(beat_a).is_less_equal(beat_b)


func test_note_has_five_fields() -> void:
	var path: String = ProjectSettings.globalize_path("res://tests/fixtures/test_song.json")
	var data: Dictionary = SongLoader.load_song(path)
	var notes: Array = data["notes"] as Array
	for note: Array in notes:
		assert_int(note.size()).is_equal(5)


func test_tempo_extracted() -> void:
	var path: String = ProjectSettings.globalize_path("res://tests/fixtures/test_song.json")
	var data: Dictionary = SongLoader.load_song(path)
	assert_float(data["tempo_bpm"] as float).is_equal(120.0)


func test_missing_file_returns_empty() -> void:
	var data: Dictionary = SongLoader.load_song("/nonexistent/path.json")
	assert_dict(data).is_empty()


func test_malformed_json_returns_empty() -> void:
	var path: String = ProjectSettings.globalize_path("res://tests/fixtures/test_song_malformed.json")
	var data: Dictionary = SongLoader.load_song(path)
	assert_dict(data).is_empty()


func test_twinkle_json_loads() -> void:
	var path: String = ProjectSettings.globalize_path("res://songs/twinkle.json")
	var data: Dictionary = SongLoader.load_song(path)
	assert_dict(data).is_not_empty()
	var notes: Array = data["notes"] as Array
	assert_int(notes.size()).is_equal(14)


func test_hand_values_valid() -> void:
	var path: String = ProjectSettings.globalize_path("res://tests/fixtures/test_song.json")
	var data: Dictionary = SongLoader.load_song(path)
	for note: Array in data["notes"] as Array:
		var hand: int = note[3] as int
		assert_bool(hand == 0 or hand == 1).is_true()
