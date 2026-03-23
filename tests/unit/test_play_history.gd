extends GdUnitTestSuite
## Tests for PlayHistory: tracking plays, favorites, stats.


func before_test() -> void:
	# Reset static state and mark as loaded so it doesn't read from disk
	PlayHistory._data = {"plays": {}, "favorites": {}, "stats": {"total_songs_played": 0, "total_sessions": 0}}
	PlayHistory._loaded = true


func test_record_play() -> void:
	PlayHistory.record_play("test_id", "Test Song", true)
	var plays: Dictionary = PlayHistory._data["plays"] as Dictionary
	assert_bool(plays.has("test_id")).is_true()
	var entry: Dictionary = plays["test_id"] as Dictionary
	assert_int(entry["play_count"] as int).is_equal(1)
	assert_int(entry["completed_count"] as int).is_equal(1)


func test_record_multiple_plays() -> void:
	PlayHistory.record_play("test_id", "Test", true)
	PlayHistory.record_play("test_id", "Test", false)
	PlayHistory.record_play("test_id", "Test", true)
	var entry: Dictionary = (PlayHistory._data["plays"] as Dictionary)["test_id"] as Dictionary
	assert_int(entry["play_count"] as int).is_equal(3)
	assert_int(entry["completed_count"] as int).is_equal(2)


func test_toggle_favorite() -> void:
	var result: bool = PlayHistory.toggle_favorite("fav_id", "Fav Song")
	assert_bool(result).is_true()
	assert_bool(PlayHistory.is_favorite("fav_id")).is_true()
	result = PlayHistory.toggle_favorite("fav_id", "Fav Song")
	assert_bool(result).is_false()
	assert_bool(PlayHistory.is_favorite("fav_id")).is_false()


func test_recently_played_sorted() -> void:
	# Manually set timestamps to ensure deterministic ordering
	PlayHistory._data["plays"]["a"] = {
		"title": "Song A", "play_count": 1, "completed_count": 1,
		"last_played": "2026-01-01T00:00:00",
	}
	PlayHistory._data["plays"]["b"] = {
		"title": "Song B", "play_count": 1, "completed_count": 1,
		"last_played": "2026-01-02T00:00:00",
	}
	PlayHistory._data["plays"]["c"] = {
		"title": "Song C", "play_count": 1, "completed_count": 1,
		"last_played": "2026-01-03T00:00:00",
	}
	var recent: Array[Dictionary] = PlayHistory.get_recently_played(10)
	assert_int(recent.size()).is_equal(3)
	assert_str(recent[0]["id"] as String).is_equal("c")
