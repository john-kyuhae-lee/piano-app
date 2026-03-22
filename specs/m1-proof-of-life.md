# M1 — Proof of Life

## Goal

A Godot window with a virtual piano keyboard at the bottom and colored blocks falling from the top. Hardcoded 8-bar melody (C major scale ascending right hand, descending left hand). No MIDI input, no file loading. Pure rendering proof.

## What the Kid Sees

Blocks falling onto a piano. Nothing interactive yet, but it looks like a game.

## Acceptance Criteria

1. **Window**: 1920×1080, Compatibility renderer, title "Piano Hero"
2. **Piano keyboard**: 88 keys (A0–C8), correct white/black layout, anchored to bottom of screen
   - White keys: visible, proportionally sized
   - Black keys: narrower, shorter, overlapping white keys
   - Keys are static (no interaction yet)
3. **Hit line**: Horizontal line above the keyboard where notes "should be played"
4. **Falling blocks**: Colored rectangles falling from top toward the hit line
   - Width matches the target key width
   - Height proportional to note duration
   - Right hand = green, Left hand = blue
   - Position = `(note_time - current_time) * pixels_per_second` (time-based, no drift)
5. **Hardcoded song**: C major scale
   - Right hand (green): C4 D4 E4 F4 G4 A4 B4 C5, quarter notes, ascending
   - Left hand (blue): C3 B2 A2 G2 F2 E2 D2 C2, quarter notes, descending
   - Both hands play simultaneously
   - Tempo: 120 BPM (0.5s per quarter note)
6. **Song loops**: When the sequence ends, it restarts (continuous demo)
7. **Performance**: 60fps with 20+ simultaneous blocks, no stuttering

## Technical Decisions

- **Renderer**: Compatibility (no Vulkan on target hardware)
- **Falling notes**: Single Node2D using `_draw()` to render all visible notes (not individual scene nodes)
- **Song time**: `_process(delta)` accumulates delta. Note Y position derived from time offset.
- **No scenes for notes**: All note rendering happens in one `_draw()` call for performance
- **Keyboard**: Scene nodes for keys (static UI, benefits from inspector editing)

## Non-Goals

- MIDI input
- File loading / JSON parsing
- Scoring / hit detection
- Audio
- Finger numbers on blocks
- Any UI beyond the gameplay viewport

## Song Data Format (Hardcoded)

```gdscript
# Each note: [midi_pitch, start_beat, duration_beats, hand]
# hand: 0 = right, 1 = left
var song_notes := [
    # Right hand - C major ascending
    [60, 0.0, 1.0, 0],  # C4
    [62, 1.0, 1.0, 0],  # D4
    [64, 2.0, 1.0, 0],  # E4
    [65, 3.0, 1.0, 0],  # F4
    [67, 4.0, 1.0, 0],  # G4
    [69, 5.0, 1.0, 0],  # A4
    [71, 6.0, 1.0, 0],  # B4
    [72, 7.0, 1.0, 0],  # C5
    # Left hand - C major descending
    [48, 0.0, 1.0, 1],  # C3
    [47, 1.0, 1.0, 1],  # B2
    [45, 2.0, 1.0, 1],  # A2
    [43, 3.0, 1.0, 1],  # G2
    [41, 4.0, 1.0, 1],  # F2
    [40, 5.0, 1.0, 1],  # E2 (corrected - E2 is MIDI 40)
    [38, 6.0, 1.0, 1],  # D2
    [36, 7.0, 1.0, 1],  # C2
]
```

## File Layout

```
project.godot
scenes/
  main.tscn              # Entry point — just holds Main node
scripts/
  game/
    main.gd              # Main scene script — owns keyboard + note renderer
    note_renderer.gd     # Draws all falling notes via _draw()
    keyboard.gd           # Draws/manages the 88-key piano keyboard
```
