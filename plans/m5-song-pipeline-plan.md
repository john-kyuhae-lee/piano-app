# M5 — Song Pipeline — Implementation Plan

## Commit Sequence

### Commit 1: Python project scaffolding
- Create `piano-prep/` with pyproject.toml, src layout
- Dependencies: music21, pianoplayer, typer, rich
- Models: SongMeta, Note, Track, Section dataclasses
- `uv sync` to create lockfile

### Commit 2: MusicXML parser + metadata extraction
- parser.py: music21 parse → extract notes with pitch, start_beat, duration_beats, hand
- metadata.py: title, composer, key, tempo, time_sig, duration
- sections.py: detect phrase boundaries (rests, 4-bar fallback)
- Difficulty computation (note density, ambitus, rhythmic complexity)

### Commit 3: Fingering computation
- fingering.py: pianoplayer wrapper with try/except
- Annotate notes with finger numbers (1–5)
- Fallback: no fingering on failure (finger = null)

### Commit 4: CLI + JSON writer
- cli.py: `piano-prep prepare <file>` command
- writer.py: serialize to game JSON format
- Test with a real .mxl file

### Commit 5: Prepare test songs
- Download/create .mxl fixtures for Twinkle, Ode to Joy, Für Elise
- Run pipeline, commit prepared JSON to songs/

### Commit 6: Godot song loader
- song_loader.gd: parse JSON, return typed arrays
- GameEngine: accept song data from loader instead of hardcoded
- Command-line song selection: `-- --song songs/twinkle.json`

### Commit 7: Finger number rendering + docs
- NoteRenderer: draw finger numbers on blocks
- Update current-milestone.md
- Run playtest to verify
