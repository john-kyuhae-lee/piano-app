# Piano Hero — Roadmap

## Vision

A dedicated "Piano Hero" app that makes classical piano practice fun for kids. Falling blocks with finger numbers guide the player through songs. Connects to a Yamaha P-125 via USB-MIDI for real-time feedback. Eventually runs as a kiosk-mode app on a dedicated laptop sitting on the piano.

## Target User

- **Player**: Young kid learning piano (uses the app in full-screen, arcade-style)
- **Admin**: Parent (loads songs, adjusts settings, does all coding/setup)

## Milestone Plan

### M1 — Proof of Life
Get a Godot window rendering a piano keyboard and falling blocks from a hardcoded sequence. No MIDI, no file loading. Pure rendering proof.

### M2 — MIDI Input
Connect to Yamaha P-125 via USB-MIDI. Detect key presses in real-time. Light up the virtual keyboard when physical keys are pressed.

### M3 — Song Loading
Parse MusicXML files into the internal note sequence format. Load a real classical piece and render it as falling blocks.

### M4 — Game Engine
Wait mode (blocks pause until correct note played). Basic scoring. Left/right hand color coding.

### M5 — Fingering Algorithm
Implement Viterbi/DP-based fingering assignment for songs without embedded fingering data. Display finger numbers (1-5) on falling blocks.

### M6 — Song Library & UI
Song selection screen. Scan a folder for available songs. Display title, difficulty, hand requirements.

### M7 — Polish & Kiosk Mode
Visual polish (glow effects, smooth animations). Omarchy auto-launch config. Boot-to-app experience.

## Non-Goals (for now)

- Sound generation (the Yamaha produces all audio)
- Recording/playback
- Online features
- OMR (scanning paper sheet music)
- Multi-player
