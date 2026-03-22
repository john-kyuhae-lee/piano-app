# M1 — Proof of Life — Implementation Plan

## Task Order

### 1. Project scaffolding
- Create `project.godot` with Compatibility renderer, 1920×1080
- Create directory structure: `scenes/`, `scripts/game/`
- Create `scenes/main.tscn` with a root Node2D

### 2. Piano keyboard (`scripts/game/keyboard.gd`)
- 88 keys: MIDI 21 (A0) through MIDI 108 (C8)
- Layout: white keys evenly spaced across screen width, black keys overlaid
- Use `_draw()` for the keyboard (static, redrawn only when needed)
- White keys: light gray fill, dark outline
- Black keys: dark fill, shorter height
- Keyboard anchored to bottom ~15% of screen height
- Expose `get_key_rect(midi_pitch) -> Rect2` so note renderer can match widths

### 3. Note renderer (`scripts/game/note_renderer.gd`)
- Hardcoded song data (C major scale, both hands)
- `_process(delta)`: accumulate `song_time`, call `queue_redraw()`
- `_draw()`: for each note, compute Y from `(note_time - song_time) * pixels_per_second`
  - Only draw notes that are visible (Y within screen bounds)
  - Block width = key width from keyboard
  - Block height = duration * pixels_per_second
  - Color: green (right hand), blue (left hand)
- Hit line: horizontal line drawn at a fixed Y above the keyboard
- Loop: when `song_time` exceeds song duration, reset to 0

### 4. Main scene (`scripts/game/main.gd`)
- Compose keyboard + note renderer as child nodes
- Set background color (dark gray/black)
- Wire up: note renderer gets reference to keyboard for key positions

### 5. Verify
- `godot --path ~/piano-app --headless --quit` to verify project loads
- Check for GDScript warnings
