# Current Milestone

## Active: M6 — Song Library & Search

**Status**: Complete

**Goal**: Searchable song library with 486 indexed pieces. Kid browses, picks a song, it prepares and plays.

**Done**:
- SQLite FTS5 corpus indexer (incremental, hash-based skip)
- music21 built-in corpus indexed (486 pieces: Bach, Mozart, Beethoven, Chopin, Haydn, Schubert, Schumann)
- CLI: `piano-prep index`, `piano-prep search`, `piano-prep search-json`
- Godot SongSearch: calls Python via OS.execute, returns JSON results
- Song list UI: "Piano Hero" title, search bar, scrollable list with difficulty stars
- Song selection: click a song → prepare (MusicXML → JSON) → play
- ESC returns to song list from gameplay
- CanvasLayer for proper Control-over-Node2D rendering

**Blockers**: None

**Next**:
- Begin M7 (Discovery & Recommendations)
