extends Node
## Global signal bus. Signals only — no methods, no state.

## MIDI signals
signal midi_note_on(pitch: int, velocity: int)
signal midi_note_off(pitch: int)
signal midi_device_connected(device_name: String)
signal midi_device_disconnected

## Game signals
signal note_cleared(pitch: int)
signal wrong_note_played
signal song_completed
signal game_state_changed(state: int)
