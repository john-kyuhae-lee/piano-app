# M3 — First Playable

## Goal

Combine M1 (falling blocks) + M2 (MIDI input) into the first playable experience. Blocks fall, pause at the hit line, and wait for the correct key. Press the right key → block clears, timeline advances. No time pressure — the kid plays at their own pace.

## What the Kid Sees

Blocks fall toward the piano. When a block reaches the line, everything pauses. Press the right key, the block flashes and disappears, and the next block starts falling. Get it wrong and the block turns red briefly. Finish all the notes and a "Song Complete!" message appears. Press any key to restart.

## Acceptance Criteria

1. **Wait mode**: Song time only advances when the correct note is played
   - Blocks fall normally until the next note reaches the hit line
   - At the hit line, song time freezes — blocks stop moving
   - Correct MIDI input → song time advances past that note
   - Multiple notes at the same beat (chords) → all must be pressed before advancing
2. **Hit detection**: Compare MIDI input pitch against the note(s) at the current song position
   - Correct note: block flashes white briefly then disappears
   - Wrong note: block(s) at hit line flash red briefly (0.3s)
3. **Song**: "Twinkle Twinkle Little Star" right hand only
   - C4 C4 G4 G4 A4 A4 G4(half) | F4 F4 E4 E4 D4 D4 C4(half)
   - Quarter notes at 100 BPM, half notes for phrase endings
4. **State machine**: Ready → Playing → Complete
   - **Ready**: "Press any key to start" label, blocks visible but frozen
   - **Playing**: wait mode active, MIDI input processed
   - **Complete**: "Song Complete!" label, press any key to restart
5. **Cleared notes stay gone** — don't redraw notes that have been hit
6. **Works without MIDI**: blocks just freeze at hit line (can't advance without input)

## Technical Decisions

- **Game engine** (`game_engine.gd`): New script owns the state machine and wait-mode logic. Sits between MIDI input and note renderer.
- **Note renderer refactored**: Receives song data + current state from game engine instead of managing its own time. Tracks which notes are cleared.
- **No scoring yet** — just correct/incorrect feedback
- **No audio** — visual feedback only

## Non-Goals

- Scoring / stars
- Left hand
- Song selection UI
- Practice mode (loop, slow down)
- Finger numbers

## Song Data

```gdscript
# Twinkle Twinkle Little Star — right hand only, 100 BPM
# [midi_pitch, start_beat, duration_beats, hand]
[60, 0.0, 1.0, 0],   # C4
[60, 1.0, 1.0, 0],   # C4
[67, 2.0, 1.0, 0],   # G4
[67, 3.0, 1.0, 0],   # G4
[69, 4.0, 1.0, 0],   # A4
[69, 5.0, 1.0, 0],   # A4
[67, 6.0, 2.0, 0],   # G4 (half note)
[65, 8.0, 1.0, 0],   # F4
[65, 9.0, 1.0, 0],   # F4
[64, 10.0, 1.0, 0],  # E4
[64, 11.0, 1.0, 0],  # E4
[62, 12.0, 1.0, 0],  # D4
[62, 13.0, 1.0, 0],  # D4
[60, 14.0, 2.0, 0],  # C4 (half note)
```

## File Changes

```
scripts/
  autoloads/
    events.gd             # Add game signals (note_cleared, song_completed)
  game/
    game_engine.gd        # NEW — state machine, wait mode, hit detection
    note_renderer.gd      # Refactored — driven by game engine, tracks cleared notes
    main.gd               # Updated — adds game engine, state labels
```
