extends Node
## Manages MIDI device connections and translates InputEventMIDI to Events signals.
## Also maps computer keyboard keys to MIDI notes for testing without a piano.

const MIDI_MESSAGE_NOTE_ON: int = 9
const MIDI_MESSAGE_NOTE_OFF: int = 8

## How often to poll for device changes (seconds).
const POLL_INTERVAL: float = 2.0

## Computer keyboard to MIDI pitch mapping (two octaves starting at C4).
## Bottom row: C4–B4, top row: C5–E5.
## Layout mirrors a piano: white keys on main row, sharps on row above.
const KEY_TO_PITCH: Dictionary = {
	# White keys — bottom row (Z-M and comma/period)
	KEY_Z: 60,   # C4
	KEY_X: 62,   # D4
	KEY_C: 64,   # E4
	KEY_V: 65,   # F4
	KEY_B: 67,   # G4
	KEY_N: 69,   # A4
	KEY_M: 71,   # B4
	KEY_COMMA: 72,  # C5
	KEY_PERIOD: 74, # D5
	KEY_SLASH: 76,  # E5
	# Black keys — row above (S, D, G, H, J, L)
	KEY_S: 61,   # C#4
	KEY_D: 63,   # D#4
	KEY_G: 66,   # F#4
	KEY_H: 68,   # G#4
	KEY_J: 70,   # A#4
	KEY_L: 73,   # C#5
	KEY_SEMICOLON: 75, # D#5
}

var _connected_device: String = ""
var _poll_timer: float = 0.0
var _keyboard_keys_held: Dictionary = {}  # keycode -> true


func _ready() -> void:
	if not DisplayServer.get_name() == "headless":
		OS.open_midi_inputs()
		_check_devices()


func _process(delta: float) -> void:
	_poll_timer += delta
	if _poll_timer >= POLL_INTERVAL:
		_poll_timer = 0.0
		_check_devices()


func _input(event: InputEvent) -> void:
	if event is InputEventMIDI:
		_handle_midi(event as InputEventMIDI)
	elif event is InputEventKey:
		_handle_keyboard(event as InputEventKey)


func _handle_midi(midi: InputEventMIDI) -> void:
	if midi.message == MIDI_MESSAGE_NOTE_ON:
		if midi.velocity > 0:
			Events.midi_note_on.emit(midi.pitch, midi.velocity)
		else:
			Events.midi_note_off.emit(midi.pitch)
	elif midi.message == MIDI_MESSAGE_NOTE_OFF:
		Events.midi_note_off.emit(midi.pitch)


func _handle_keyboard(key: InputEventKey) -> void:
	if key.echo:
		return  # Ignore key repeat
	var keycode: int = key.keycode
	if not KEY_TO_PITCH.has(keycode):
		return
	var pitch: int = KEY_TO_PITCH[keycode] as int

	if key.pressed and not _keyboard_keys_held.has(keycode):
		_keyboard_keys_held[keycode] = true
		Events.midi_note_on.emit(pitch, 80)
	elif not key.pressed and _keyboard_keys_held.has(keycode):
		_keyboard_keys_held.erase(keycode)
		Events.midi_note_off.emit(pitch)


func _check_devices() -> void:
	var devices: PackedStringArray = OS.get_connected_midi_inputs()
	if devices.size() > 0:
		var device_name: String = devices[0]
		if _connected_device != device_name:
			_connected_device = device_name
			Events.midi_device_connected.emit(device_name)
	else:
		if _connected_device != "":
			_connected_device = ""
			Events.midi_device_disconnected.emit()
