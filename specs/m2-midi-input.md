# M2 — The Piano Talks Back

## Goal

Connect to the Yamaha P-125 (or any USB-MIDI keyboard) via Godot's built-in MIDI support. When a key is pressed on the real piano, the corresponding virtual key lights up on screen. No gameplay yet — pure input proof.

## What the Kid Sees

Press a piano key, the screen reacts instantly. A status label shows whether the piano is connected.

## Acceptance Criteria

1. **Events autoload**: Signal bus with `midi_note_on(pitch, velocity)` and `midi_note_off(pitch)` signals
2. **MidiManager autoload**: Listens for `InputEventMIDI`, translates to signals on Events bus
   - Opens MIDI inputs on `_ready()`
   - Handles Note On (message 9), Note Off (message 8), and velocity-0 Note On (= Note Off)
   - Emits `midi_device_connected(device_name)` / `midi_device_disconnected` via Events
   - Periodically polls for device connect/disconnect (MIDI has no hotplug callback in Godot)
3. **Keyboard visual feedback**: Pressed keys change color
   - Right-half keys (≥ MIDI 60 / C4): green highlight
   - Left-half keys (< MIDI 60): blue highlight
   - Returns to normal color on Note Off
4. **Connection status label**: Top-left corner showing "🎹 Connected: Yamaha P-125" or "No MIDI device"
5. **Works without MIDI device**: App runs normally, just shows "No MIDI device" — falling blocks still work

## Technical Decisions

- **Two autoloads**: `Events` (signals only) and `MidiManager` (MIDI I/O). Per conventions, max 3 autoloads total.
- **Signal flow**: MidiManager → Events bus → Keyboard listens
- **Keyboard keeps `_draw()`**: Add a `_pressed_keys` dictionary tracking which keys are held, redraw with highlight color
- **MIDI polling**: Check `OS.get_connected_midi_inputs()` every 2 seconds to detect connect/disconnect. Godot has no hotplug event.
- **No sustain pedal handling yet** — just note on/off

## Non-Goals

- Hit detection / scoring
- Gameplay interaction with falling blocks
- Audio output
- Latency measurement UI (we'll observe visually — target is <16ms / 1 frame)
- Finger numbers

## File Layout

```
scripts/
  autoloads/
    events.gd             # Signal bus (autoload)
    midi_manager.gd       # MIDI input handling (autoload)
  game/
    keyboard.gd           # Updated — adds highlight on MIDI input
    main.gd               # Updated — adds connection status label
```
