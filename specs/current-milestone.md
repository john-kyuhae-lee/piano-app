# Current Milestone

## Active: M7 — Discovery & Recommendations

**Status**: Complete

**Goal**: After finishing a song, recommend similar pieces. Track play history and favorites.

**Done**:
- Content-based recommendation engine (difficulty, tempo, key, density, composer similarity)
- Precomputed top-20 neighbors per song in SQLite (9720 pairs for 486 songs)
- CLI: `piano-prep recommend` (precompute), `piano-prep recommend-json` (Godot integration)
- Godot SongSearch.get_recommendations() — returns similar songs
- Song completion screen shows "Try these next:" with 3 recommendations
- Play history tracking (user://play_history.json) — play count, completed count, last played
- Favorites system (toggle, persist)

**Blockers**: None

**Next**:
- Begin M8 (Game Feel & Practice Mode — 3 modes, scoring, visual polish)
