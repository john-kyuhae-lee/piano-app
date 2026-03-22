# M4 — Debug Observability — Implementation Plan

## Commit Sequence

### Commit 1: Add DebugTelemetry autoload
- Create `scripts/autoloads/debug_telemetry.gd`
- Connect to all Events bus signals
- Write JSONL to `user://debug_telemetry.jsonl`
- Heartbeat every 30 frames
- Summary on song complete
- Register in `project.godot`, gated behind `--telemetry`

### Commit 2: Add DebugCapture autoload
- Create `scripts/autoloads/debug_capture.gd`
- Viewport screenshot via `get_viewport().get_texture().get_image().save_png()`
- Auto-capture on: READY, PLAYING, first note cleared, COMPLETE
- Register in `project.godot`, gated behind `--capture`

### Commit 3: Update test harness + commit keyboard mapping
- Commit the keyboard-to-MIDI changes in MidiManager (from M3 branch)
- Rewrite `playtest.sh` to use ydotool + telemetry + capture
- Full Twinkle Twinkle sequence with verification

### Commit 4: Update roadmap + milestone docs
- Roadmap renumbered (M4=observability, M5-M9 shifted)
- M4 spec and plan
- Update current-milestone.md
