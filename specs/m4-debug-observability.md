# M4 — Debug Observability

## Goal

Automated testing and visual inspection loop so the AI agent can self-test every change without manual human involvement. Three observation layers: structured telemetry (timing/state), strategic screenshots (visuals), and a test harness that orchestrates it all.

## What the Kid Sees

Nothing. All debug features are gated behind command-line flags and have zero cost in normal play.

## Acceptance Criteria

### 1. DebugTelemetry autoload
- Connects to Events bus signals: `midi_note_on`, `note_cleared`, `wrong_note_played`, `song_completed`, `game_state_changed`
- Writes JSONL to `user://debug_telemetry.jsonl`
- Each event line includes: frame number, timestamp_ms, song_time, state, event type, event data, FPS
- Heartbeat entry every 30 frames with FPS + state (catches frame drops between events)
- Summary entry on song complete: total time, notes cleared, wrong notes, min/avg/max FPS
- Gated behind `-- --telemetry` user arg
- Reads `song_time`, `state`, `cleared_notes` from GameEngine (via node path, not coupling)

### 2. DebugCapture autoload
- Uses `get_viewport().get_texture().get_image().save_png()` for pixel-perfect viewport capture
- Auto-captures on state transitions: READY, PLAYING (first frame), first note at hit line, first note cleared, COMPLETE
- Saves to `user://captures/{frame}_{label}.png`
- Gated behind `-- --capture` user arg
- Can also be triggered manually via `capture(label)` method

### 3. Keyboard-to-MIDI mapping (already done in M3 PR)
- Computer keyboard maps to piano keys for testing without physical Yamaha
- ydotool sends kernel-level keypresses that Godot receives

### 4. Test harness script
- `scripts/tools/playtest.sh` — launches Godot with `-- --telemetry --capture`, sends ydotool key sequence for Twinkle Twinkle, waits for song complete, copies out results
- Returns structured output: path to JSONL, paths to screenshots
- Exit code reflects pass/fail (all notes cleared = pass)

## Technical Decisions

- **JSONL not JSON**: One line per event, appendable, no need to parse full file to read latest entries
- **Viewport capture not grim**: `get_viewport().get_texture()` captures exactly what the game renders — no compositor artifacts, window decorations, or focus race conditions
- **User args not project settings**: `OS.get_cmdline_user_args()` reads args after `--`. This means `godot --path . -- --telemetry` enables it. Zero overhead when not passed.
- **Autoloads not scene nodes**: Telemetry and capture need to survive scene changes (future milestone)

## Non-Goals

- Video recording pipeline (use `--write-movie` manually when needed)
- Performance profiling beyond FPS monitoring
- Automated visual diff / regression testing

## File Layout

```
scripts/
  autoloads/
    debug_telemetry.gd   # NEW — JSONL event logger
    debug_capture.gd     # NEW — viewport screenshot on state transitions
  tools/
    playtest.sh          # UPDATED — full test harness with telemetry + capture
    screenshot.sh        # EXISTS — simple screenshot tool (kept for quick checks)
```
