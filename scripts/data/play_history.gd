class_name PlayHistory
extends RefCounted
## Tracks play history, favorites, and stats. Persists to user://play_history.json.

const HISTORY_PATH := "user://play_history.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true

	if FileAccess.file_exists(HISTORY_PATH):
		var file := FileAccess.open(HISTORY_PATH, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				_data = json.data as Dictionary
			file.close()

	if not _data.has("plays"):
		_data["plays"] = {}
	if not _data.has("favorites"):
		_data["favorites"] = {}
	if not _data.has("stats"):
		_data["stats"] = {"total_songs_played": 0, "total_sessions": 0}


static func record_play(song_id: String, title: String, completed: bool) -> void:
	"""Record that a song was played."""
	_ensure_loaded()

	var plays: Dictionary = _data["plays"] as Dictionary
	if not plays.has(song_id):
		plays[song_id] = {
			"title": title,
			"play_count": 0,
			"completed_count": 0,
			"last_played": "",
		}

	var entry: Dictionary = plays[song_id] as Dictionary
	entry["play_count"] = (entry["play_count"] as int) + 1
	if completed:
		entry["completed_count"] = (entry["completed_count"] as int) + 1
	entry["last_played"] = Time.get_datetime_string_from_system()

	var stats: Dictionary = _data["stats"] as Dictionary
	stats["total_songs_played"] = (stats["total_songs_played"] as int) + 1

	_save()


static func toggle_favorite(song_id: String, title: String) -> bool:
	"""Toggle favorite status. Returns new favorite state."""
	_ensure_loaded()

	var favorites: Dictionary = _data["favorites"] as Dictionary
	if favorites.has(song_id):
		favorites.erase(song_id)
		_save()
		return false
	else:
		favorites[song_id] = {"title": title}
		_save()
		return true


static func is_favorite(song_id: String) -> bool:
	_ensure_loaded()
	return (_data["favorites"] as Dictionary).has(song_id)


static func get_recently_played(limit: int = 10) -> Array[Dictionary]:
	"""Get recently played songs sorted by last_played descending."""
	_ensure_loaded()

	var plays: Dictionary = _data["plays"] as Dictionary
	var entries: Array[Dictionary] = []
	for song_id: String in plays:
		var entry: Dictionary = (plays[song_id] as Dictionary).duplicate()
		entry["id"] = song_id
		entries.append(entry)

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.get("last_played", "") as String) > (b.get("last_played", "") as String)
	)

	return entries.slice(0, limit)


static func get_stats() -> Dictionary:
	_ensure_loaded()
	return _data.get("stats", {}) as Dictionary


static func _save() -> void:
	var file := FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_data, "\t"))
		file.close()
