class_name SongSearch
extends RefCounted
## Searches the song corpus by calling the Python piano-prep CLI.
## Returns results as an array of dictionaries.

static func search(query: String, limit: int = 20) -> Array[Dictionary]:
	"""Search the corpus for songs matching the query."""
	var project_dir: String = ProjectSettings.globalize_path("res://")
	var db_path: String = project_dir + "corpus.db"
	var prep_dir: String = project_dir + "piano-prep"

	var output: Array = []
	# Use bash -c to suppress Python warnings that pollute stdout
	var home: String = OS.get_environment("HOME")
	var uv_path: String = home + "/.local/bin/uv"
	var cmd: String = (
		"PYTHONWARNINGS=ignore '%s' run --project '%s' piano-prep search-json '%s' --db-path '%s' --limit %d"
		% [uv_path, prep_dir, query.replace("'", ""), db_path, limit]
	)

	var exit_code: int = OS.execute("bash", ["-c", cmd], output, true)
	if exit_code != 0 or output.is_empty():
		push_warning("SongSearch: search failed (exit " + str(exit_code) + ")")
		return []

	# Parse JSON output
	var json := JSON.new()
	var err: Error = json.parse(output[0] as String)
	if err != OK:
		push_warning("SongSearch: JSON parse error: " + json.get_error_message())
		return []

	if json.data is Array:
		var results: Array[Dictionary] = []
		for item: Variant in json.data as Array:
			if item is Dictionary:
				results.append(item as Dictionary)
		return results
	return []


static func get_all_songs(limit: int = 100) -> Array[Dictionary]:
	"""Get all songs sorted by title."""
	return search("", limit)


static func get_recommendations(song_id: String, limit: int = 5) -> Array[Dictionary]:
	"""Get recommended songs similar to the given song."""
	var project_dir: String = ProjectSettings.globalize_path("res://")
	var db_path: String = project_dir + "corpus.db"
	var prep_dir: String = project_dir + "piano-prep"
	var output: Array = []

	var home: String = OS.get_environment("HOME")
	var uv_path: String = home + "/.local/bin/uv"
	var cmd: String = (
		"PYTHONWARNINGS=ignore '%s' run --project '%s' piano-prep recommend-json '%s' --db-path '%s' --limit %d"
		% [uv_path, prep_dir, song_id, db_path, limit]
	)

	var exit_code: int = OS.execute("bash", ["-c", cmd], output, true)
	if exit_code != 0 or output.is_empty():
		return []

	var json := JSON.new()
	var err: Error = json.parse(output[0] as String)
	if err != OK:
		return []

	if json.data is Array:
		var results: Array[Dictionary] = []
		for item: Variant in json.data as Array:
			if item is Dictionary:
				results.append(item as Dictionary)
		return results
	return []


static func prepare_song(song_id: String, file_path: String) -> String:
	"""Prepare a song for play (MusicXML → game JSON). Returns output path."""
	var project_dir: String = ProjectSettings.globalize_path("res://")
	var prep_dir: String = project_dir + "piano-prep"
	var songs_dir: String = project_dir + "songs"
	var output: Array = []

	var home: String = OS.get_environment("HOME")
	var uv_path: String = home + "/.local/bin/uv"
	var cmd: String = (
		"PYTHONWARNINGS=ignore '%s' run --project '%s' piano-prep prepare '%s' --output-dir '%s' --skip-fingering"
		% [uv_path, prep_dir, file_path, songs_dir]
	)

	var exit_code: int = OS.execute("bash", ["-c", cmd], output, true)
	if exit_code != 0:
		push_warning("SongSearch: prepare failed for " + file_path)
		return ""

	# Find the output file
	var json_path: String = songs_dir + "/" + song_id + ".json"
	if FileAccess.file_exists(json_path):
		return json_path

	# Try to find any new .json file
	var dir := DirAccess.open(songs_dir)
	if dir:
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			if fname.ends_with(".json"):
				return songs_dir + "/" + fname
			fname = dir.get_next()

	return ""
