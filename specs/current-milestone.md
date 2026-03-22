# Current Milestone

## Active: M4 — Debug Observability

**Status**: Complete

**Goal**: Automated testing loop — AI agent can launch game, play it via ydotool, and observe results through structured telemetry + viewport screenshots.

**Done**:
- DebugTelemetry autoload — JSONL event logger (frame, song_time, state, FPS, input events)
- DebugCapture autoload — viewport screenshots on state transitions (Ready, Playing, first clear, Complete)
- Keyboard-to-MIDI mapping in MidiManager (Z=C4, X=D4, etc.)
- playtest.sh test harness — launches game, plays Twinkle via ydotool, collects results
- Verified: 14/14 notes cleared, 0 wrong notes, avg 57.8 FPS
- Roadmap renumbered (M4=observability, M5-M9 shifted)

**Blockers**: None

**Next**:
- Begin M5 spec (Song Pipeline & Fingering)
