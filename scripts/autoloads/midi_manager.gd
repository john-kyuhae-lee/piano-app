extends Node
## Manages MIDI device connections and translates InputEventMIDI to Events signals.

const MIDI_MESSAGE_NOTE_ON: int = 9
const MIDI_MESSAGE_NOTE_OFF: int = 8

## How often to poll for device changes (seconds).
const POLL_INTERVAL: float = 2.0

var _connected_device: String = ""
var _poll_timer: float = 0.0


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
	if not event is InputEventMIDI:
		return

	var midi: InputEventMIDI = event as InputEventMIDI
	var message: int = midi.message >> 4 if midi.message >= 0x80 else midi.message

	# Godot 4.x exposes message as the MIDIMessage enum value directly.
	# Note On = 9, Note Off = 8. Velocity-0 Note On counts as Note Off.
	if midi.message == MIDI_MESSAGE_NOTE_ON:
		if midi.velocity > 0:
			Events.midi_note_on.emit(midi.pitch, midi.velocity)
		else:
			Events.midi_note_off.emit(midi.pitch)
	elif midi.message == MIDI_MESSAGE_NOTE_OFF:
		Events.midi_note_off.emit(midi.pitch)


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
