# Current Milestone

## Active: M2 — The Piano Talks Back

**Status**: Complete

**Goal**: Connect to Yamaha P-125 (or any USB-MIDI keyboard) via Godot's built-in MIDI. When a key is pressed on the real piano, the virtual key lights up on screen.

**Done**:
- M1 complete (falling blocks + keyboard rendering)
- Events signal bus autoload (signals only — midi_note_on/off, device_connected/disconnected)
- MidiManager autoload (InputEventMIDI handling, device polling every 2s)
- Keyboard MIDI highlight (green for right hand, blue for left hand)
- MIDI connection status label (top-left corner)
- Verified: runs clean with and without MIDI device

**Blockers**: None

**Next**:
- Test with physical Yamaha P-125 when available
- Begin M3 (First Playable — combine falling blocks + MIDI input + wait mode)
