# M5 — Song Pipeline & Fingering

## Goal

Build the automated song preparation pipeline. MusicXML in, game-ready JSON with fingering out. Load prepared songs in Godot. Display finger numbers on blocks. Test with real songs.

## What the Kid Sees

Real songs appear and each block has a finger number (1–5). They're learning proper technique while playing.

## Acceptance Criteria

### 1. Song JSON format (the contract between Python pipeline and Godot game)

```json
{
  "meta": {
    "title": "Für Elise",
    "composer": "Beethoven",
    "difficulty": 3.2,
    "tempo_bpm": 70,
    "time_signature": [3, 8],
    "duration_seconds": 180,
    "key": "A minor"
  },
  "sections": [
    {"start_beat": 0, "end_beat": 16, "label": "A"},
    {"start_beat": 16, "end_beat": 32, "label": "B"}
  ],
  "tracks": [
    {
      "hand": "right",
      "notes": [
        {"pitch": 76, "start_beat": 0.0, "duration_beats": 0.5, "finger": 4}
      ]
    },
    {
      "hand": "left",
      "notes": [
        {"pitch": 40, "start_beat": 0.0, "duration_beats": 2.0, "finger": 5}
      ]
    }
  ]
}
```

### 2. Python preparation tool (`piano-prep`)
- `uv` project with `src/piano_prep/` layout
- CLI via `typer`: `uv run piano-prep prepare <file.mxl>`
- Parse MusicXML with `music21`
- Compute fingering with `pianoplayer` (try/except — non-fatal if it fails)
- Split left/right hand tracks
- Detect section boundaries (rests, 4-bar fallback)
- Compute difficulty (note density, ambitus, rhythmic complexity → 1–10 scale)
- Extract metadata (title, composer, key, tempo, time signature)
- Output: `songs/{song_id}.json`

### 3. Godot song loader
- `SongLoader` class: reads prepared JSON, returns typed song data
- `GameEngine` refactored to accept song data from loader instead of hardcoded notes
- Song selection: command-line arg for now (`godot --path . -- --song songs/fur_elise.json`)

### 4. Finger number rendering
- Large bold number (1–5) centered on each falling block
- White text on colored background
- Numbers visible at all zoom levels / block sizes

### 5. Test with real songs
- Twinkle Twinkle Little Star (beginner)
- Ode to Joy (beginner)
- Für Elise opening (intermediate, right hand)

## Technical Decisions

- **music21 memory**: parse one file, extract data, `del score` + `gc.collect()`
- **pianoplayer**: wrap in try/except, produce JSON without fingering on failure
- **Section detection**: look for rests > 1 beat in melody, then fall back to 4-bar groups
- **Difficulty formula**: weighted combination of note density, pitch range (ambitus), rhythmic complexity
- **Song ID**: SHA256 of source file content, first 12 hex chars

## Non-Goals

- Corpus indexing (M6)
- SQLite search (M6)
- Song selection UI in Godot (M6)
- Batch processing (M6)

## File Layout

```
piano-prep/
  pyproject.toml
  src/piano_prep/
    __init__.py
    cli.py              # Typer CLI
    parser.py           # music21 MusicXML → internal model
    fingering.py        # pianoplayer wrapper
    metadata.py         # key, tempo, difficulty extraction
    sections.py         # phrase boundary detection
    models.py           # dataclasses (SongMeta, Note, Track, Section)
    writer.py           # write game JSON
  tests/
    fixtures/           # small .mxl test files
    test_parser.py
    test_writer.py
songs/                  # prepared game JSON (gitignored in production, committed for M5 test songs)
scripts/
  data/
    song_loader.gd      # reads JSON, returns typed data
  game/
    game_engine.gd      # refactored — accepts song data from loader
    note_renderer.gd    # updated — draws finger numbers on blocks
```
