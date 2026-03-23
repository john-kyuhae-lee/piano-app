extends GdUnitTestSuite
## Tests for PlayHistory: tracking plays, favorites, stats.


func test_record_play() -> void:
	PlayHistory._loaded = false
	PlayHistory._data = {}
	PlayHistory.record_play("test_id", "Test Song", true)
	var plays: Dictionary = PlayHistory._data["plays"] as Dictionary
	assert_bool(plays.has("test_id")).is_true()
	var entry: Dictionary = plays["test_id"] as Dictionary
	assert_int(entry["play_count"] as int).is_equal(1)
	assert_int(entry["completed_count"] as int).is_equal(1)


func test_record_multiple_plays() -> void:
	PlayHistory._loaded = false
	PlayHistory._data = {}
	PlayHistory.record_play("test_id", "Test", true)
	PlayHistory.record_play("test_id", "Test", false)
	PlayHistory.record_play("test_id", "Test", true)
	var entry: Dictionary = (PlayHistory._data["plays"] as Dictionary)["test_id"] as Dictionary
	assert_int(entry["play_count"] as int).is_equal(3)
	assert_int(entry["completed_count"] as int).is_equal(2)


func test_toggle_favorite() -> void:
	PlayHistory._loaded = false
	PlayHistory._data = {}
	PlayHistory._ensure_loaded()
	var result: bool = PlayHistory.toggle_favorite("fav_id", "Fav Song")
	assert_bool(result).is_true()
	assert_bool(PlayHistory.is_favorite("fav_id")).is_true()
	result = PlayHistory.toggle_favorite("fav_id", "Fav Song")
	assert_bool(result).is_false()
	assert_bool(PlayHistory.is_favorite("fav_id")).is_false()


func test_recently_played_sorted() -> void:
	PlayHistory._loaded = false
	PlayHistory._data = {}
	PlayHistory.record_play("a", "Song A", true)
	PlayHistory.record_play("b", "Song B", true)
	PlayHistory.record_play("c", "Song C", true)
	var recent: Array[Dictionary] = PlayHistory.get_recently_played(10)
	assert_int(recent.size()).is_equal(3)
	# Most recent should be first (c was last recorded)
	assert_str(recent[0]["id"] as String).is_equal("c")
