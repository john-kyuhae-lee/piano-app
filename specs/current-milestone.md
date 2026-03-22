# Current Milestone

## Active: M5 — Song Pipeline & Fingering

**Status**: Complete

**Goal**: MusicXML → game-ready JSON pipeline. Load real songs in Godot. Display finger numbers on blocks.

**Done**:
- Python `piano-prep` tool with uv project, src layout
- MusicXML parser (music21): extracts notes with pitch, beat, duration, hand split
- Metadata extraction: title, composer, key, tempo, time signature, difficulty (1-10)
- Section boundary detection: rests + 4-bar fallback
- Fingering wrapper (pianoplayer): try/except, non-fatal on failure
- CLI: `piano-prep <file.mxl>` with progress output
- JSON writer: game-ready format with meta, sections, tracks
- Test songs: Twinkle Twinkle, Ode to Joy (prepared as JSON)
- Godot SongLoader: reads JSON, returns typed note arrays
- GameEngine refactored: accepts song data from loader, dynamic BPM
- Command-line song selection: `-- --song songs/twinkle.json`
- Finger number rendering on blocks (white text, centered)

**Blockers**: None

**Next**:
- Install pianoplayer and prepare songs with actual fingering
- Begin M6 spec (Song Library & Search)
