class_name SongSearch
extends RefCounted
## Searches the song corpus by calling the Python piano-prep CLI.
## All methods are synchronous (blocking). Callers should run on threads.

static func _get_uv_path() -> String:
	return OS.get_environment("HOME") + "/.local/bin/uv"


static func _get_project_dir() -> String:
	return ProjectSettings.globalize_path("res://")


static func search(query: String, limit: int = 20) -> Array[Dictionary]:
	"""Search the corpus. BLOCKING — run on a thread."""
	var project_dir: String = _get_project_dir()
	var db_path: String = project_dir + "corpus.db"
	var prep_dir: String = project_dir + "piano-prep"
	var output: Array = []

	var cmd: String = (
		"PYTHONWARNINGS=ignore '%s' run --project '%s' piano-prep search-json '%s' --db-path '%s' --limit %d"
		% [_get_uv_path(), prep_dir, query.replace("'", ""), db_path, limit]
	)

	var exit_code: int = OS.execute("bash", ["-c", cmd], output, true)
	if exit_code != 0 or output.is_empty():
		return []

	return _parse_json_array(output[0] as String)


static func get_all_songs(limit: int = 100) -> Array[Dictionary]:
	return search("", limit)


static func get_recommendations(song_id: String, limit: int = 5) -> Array[Dictionary]:
	"""Get recommendations. BLOCKING — run on a thread."""
	var project_dir: String = _get_project_dir()
	var db_path: String = project_dir + "corpus.db"
	var prep_dir: String = project_dir + "piano-prep"
	var output: Array = []

	var cmd: String = (
		"PYTHONWARNINGS=ignore '%s' run --project '%s' piano-prep recommend-json '%s' --db-path '%s' --limit %d"
		% [_get_uv_path(), prep_dir, song_id, db_path, limit]
	)

	var exit_code: int = OS.execute("bash", ["-c", cmd], output, true)
	if exit_code != 0 or output.is_empty():
		return []

	return _parse_json_array(output[0] as String)


static func prepare_song(file_path: String, output_name: String) -> String:
	"""Prepare a song. BLOCKING — run on a thread. Returns output path."""
	var project_dir: String = _get_project_dir()
	var prep_dir: String = project_dir + "piano-prep"
	var songs_dir: String = project_dir + "songs"
	var output: Array = []

	# Use the database song ID as the output filename
	var output_path: String = songs_dir + "/" + output_name + ".json"

	# Prepare with music21 (supports .mxl, .xml, .krn, .mid and more)
	var cmd: String = (
		"PYTHONWARNINGS=ignore '%s' run --project '%s' piano-prep prepare '%s' --output-dir '%s' --skip-fingering 2>&1"
		% [_get_uv_path(), prep_dir, file_path, songs_dir]
	)

	var exit_code: int = OS.execute("bash", ["-c", cmd], output, true)
	if exit_code != 0:
		push_warning("SongSearch: prepare failed (exit %d) for %s" % [exit_code, file_path])
		# Check if a file was written anyway (sometimes exit code lies)

	# Find the prepared file — look for any new .json matching the recent prepare
	var dir := DirAccess.open(songs_dir)
	if dir:
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			if fname.ends_with(".json") and fname != "twinkle.json" and fname != "ode_to_joy.json":
				var full_path: String = songs_dir + "/" + fname
				# Rename to the expected name
				if full_path != output_path:
					DirAccess.rename_absolute(full_path, output_path)
				return output_path
			fname = dir.get_next()

	return ""


static func _parse_json_array(text: String) -> Array[Dictionary]:
	var json := JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		return []
	if json.data is Array:
		var results: Array[Dictionary] = []
		for item: Variant in json.data as Array:
			if item is Dictionary:
				results.append(item as Dictionary)
		return results
	return []
