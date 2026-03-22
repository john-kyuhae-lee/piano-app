extends Node
## Global signal bus. Signals only — no methods, no state.

## MIDI signals
signal midi_note_on(pitch: int, velocity: int)
signal midi_note_off(pitch: int)
signal midi_device_connected(device_name: String)
signal midi_device_disconnected
