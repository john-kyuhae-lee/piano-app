# M2 — The Piano Talks Back — Implementation Plan

## Commit Sequence

### Commit 1: Add Events signal bus autoload
- Create `scripts/autoloads/events.gd` — signals only, no methods, no state
- Register in `project.godot` as autoload
- Signals: `midi_note_on`, `midi_note_off`, `midi_device_connected`, `midi_device_disconnected`

### Commit 2: Add MidiManager autoload
- Create `scripts/autoloads/midi_manager.gd`
- `_ready()`: call `OS.open_midi_inputs()`
- `_input()`: handle `InputEventMIDI` — Note On (channel 9), Note Off (channel 8), velocity-0 Note On
- Emit through Events bus
- Poll `OS.get_connected_midi_inputs()` every 2 seconds via timer
- Register in `project.godot` as autoload

### Commit 3: Keyboard MIDI highlight
- Update `keyboard.gd` to connect to `Events.midi_note_on` / `Events.midi_note_off`
- Track `_pressed_keys: Dictionary` (midi_pitch → true)
- In `_draw()`, render pressed keys with highlight color (green for right, blue for left)
- `queue_redraw()` on note on/off

### Commit 4: Connection status UI + update milestone
- Update `main.gd` to add a Label showing MIDI connection status
- Connect to `Events.midi_device_connected` / `Events.midi_device_disconnected`
- Add M2 spec, plan, update current-milestone.md
