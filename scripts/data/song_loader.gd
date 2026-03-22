class_name SongLoader
extends RefCounted
## Loads prepared song JSON files into typed game data.

## Note format matching GameEngine: [pitch, start_beat, duration_beats, hand, finger]
## hand: 0 = right, 1 = left
## finger: 0 = none, 1-5 = finger number

const RIGHT_HAND: int = 0
const LEFT_HAND: int = 1


static func load_song(path: String) -> Dictionary:
	"""Load a song JSON file and return a Dictionary with notes, meta, sections."""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SongLoader: Could not open " + path)
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var err: Error = json.parse(json_text)
	if err != OK:
		push_error("SongLoader: JSON parse error in " + path + ": " + json.get_error_message())
		return {}

	var data: Dictionary = json.data as Dictionary
	return _process_song_data(data)


static func _process_song_data(data: Dictionary) -> Dictionary:
	"""Convert raw JSON into game-ready format."""
	var notes: Array[Array] = []
	var meta: Dictionary = data.get("meta", {})
	var sections: Array = data.get("sections", [])

	var tracks: Array = data.get("tracks", [])
	for track: Dictionary in tracks:
		var hand_str: String = track.get("hand", "right") as String
		var hand: int = LEFT_HAND if hand_str == "left" else RIGHT_HAND

		var track_notes: Array = track.get("notes", [])
		for note: Dictionary in track_notes:
			var pitch: int = note.get("pitch", 60) as int
			var start_beat: float = note.get("start_beat", 0.0) as float
			var duration_beats: float = note.get("duration_beats", 1.0) as float
			var finger_val: Variant = note.get("finger", null)
			var finger: int = finger_val as int if finger_val != null else 0

			notes.append([pitch, start_beat, duration_beats, hand, finger])

	# Sort by start_beat then pitch
	notes.sort_custom(func(a: Array, b: Array) -> bool:
		if a[1] != b[1]:
			return a[1] < b[1]
		return a[0] < b[0]
	)

	return {
		"notes": notes,
		"meta": meta,
		"sections": sections,
		"tempo_bpm": meta.get("tempo_bpm", 120) as float,
	}
