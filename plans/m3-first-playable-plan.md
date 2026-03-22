# M3 — First Playable — Implementation Plan

## Commit Sequence

### Commit 1: Add game signals to Events bus
- `note_cleared(pitch: int)` — a note was correctly hit
- `song_completed` — all notes cleared
- `game_state_changed(state: int)` — Ready/Playing/Complete

### Commit 2: Add GameEngine with wait mode + hit detection
- State machine: READY → PLAYING → COMPLETE
- Owns song data (Twinkle Twinkle, right hand, 100 BPM)
- Sorts notes by start_beat, groups notes at the same beat into "events"
- Tracks current event index — which group of notes is next
- Wait mode: exposes `song_time` that only advances when not waiting
- On `midi_note_on`: check if pitch matches any note in current event
  - If all notes in event are hit → advance to next event, emit `note_cleared`
  - If wrong note → emit signal for visual feedback
- On last event cleared → emit `song_completed`
- Exposes state + song_time + cleared set for renderer to read

### Commit 3: Refactor NoteRenderer for game engine integration
- Remove internal song data and time tracking
- Read song_time, song data, and cleared notes from GameEngine
- Add visual feedback: flash white on clear, flash red on wrong note
- Skip drawing cleared notes
- Hit line stays the same

### Commit 4: Update Main with state labels + game wiring
- Add GameEngine as child, wire to renderer
- "Press any key to start" label (Ready state)
- "Song Complete!" label (Complete state)
- Any MIDI key in Ready/Complete → transition state
- Add M3 spec, plan, update current-milestone.md
