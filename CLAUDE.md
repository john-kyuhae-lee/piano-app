# Piano Hero — Project Directives

A "Guitar Hero"-style piano learning app for kids, built with Godot Engine. Connects to a Yamaha P-125 via USB-MIDI. Falling blocks with classical fingering numbers (1-5) guide the player through songs. Kid has full autonomy to search, discover, and explore a local library of 10K-30K piano pieces.

## Tech Stack

- **Game**: Godot 4.3+ (GDScript, Forward+ renderer with Compatibility fallback)
- **Song Pipeline**: Python 3.10+ (`music21`, `pianoplayer`, `typer`, `rich`)
- **Package Manager**: `uv` (for Python tooling)
- **Corpus**: PDMX dataset (250K+ public domain MusicXML, CC-BY)
- **Search Index**: SQLite with FTS5
- **MIDI**: Godot built-in (`InputEventMIDI`, `OS.get_connected_midi_inputs()`)
- **Target**: Linux x86_64 (Omarchy/Arch), Yamaha P-125 via USB-MIDI

## Project Structure

```
piano-app/
  project.godot                    # Godot project config
  scenes/                          # Scene files (.tscn)
    main.tscn                      # Entry point
    game/                          # Gameplay scenes (note renderer, keyboard, hit line)
    ui/                            # Song search, library, settings, results
  scripts/                         # GDScript files (.gd)
    autoloads/                     # Events bus, MidiManager, Config
    game/                          # Game engine, scoring, state machine
    rendering/                     # Note drawing (_draw), keyboard, effects
    data/                          # Song loading, JSON parsing
  assets/                          # Fonts, textures, audio samples
  songs/                           # Prepared game JSON (cached, gitignored)
  piano-prep/                      # Python CLI tool (src layout)
    src/piano_prep/
      cli.py                       # Typer CLI entry point
      parser.py                    # music21 MusicXML parsing
      fingering.py                 # pianoplayer wrapper
      metadata.py                  # Key, tempo, difficulty extraction
      indexer.py                   # SQLite corpus builder
      models.py                    # Dataclasses (SongMeta, Note, Track)
      db.py                        # SQLite helpers
    tests/
      fixtures/                    # Small test .mxl files
    pyproject.toml
    uv.lock
  corpus/                          # Raw .mxl files (gitignored, large)
  corpus.db                        # SQLite search index (gitignored)
  specs/                           # Milestone specs
  plans/                           # Implementation plans
```

## Dev Commands

```bash
# Godot
godot --path . --editor           # open editor
godot --path . --debug            # run game
godot --path .                    # run without debug overlay

# Python pipeline
cd piano-prep
uv sync                           # install deps from lockfile
uv run piano-prep prepare song.mxl  # prepare a single song
uv run piano-prep index corpus/    # build/update search index
uv run piano-prep search "beethoven" # search the index
uv run pytest                      # run tests
uv run pytest -m "not slow"        # skip pianoplayer tests
```

## Pre-PR Verification

```
[ ] Game runs without errors (godot --path . --debug)
[ ] No GDScript warnings (typed, no unsafe access)
[ ] Python tests pass (uv run pytest)
[ ] Python linting passes (uv run ruff check)
```

---

## GDScript Conventions

Full conventions in `specs/GODOT_CONVENTIONS.md`. Key rules:

### Naming

| Thing | Convention | Example |
|-------|-----------|---------|
| Files | `snake_case.gd` | `note_renderer.gd` |
| Classes | `PascalCase` | `class_name NoteRenderer` |
| Nodes | `PascalCase` | `FallingNote`, `ScoreLabel` |
| Functions | `snake_case` | `func spawn_note():` |
| Variables | `snake_case` | `var scroll_speed: float` |
| Signals | `snake_case`, past tense | `signal note_hit` |
| Constants | `SCREAMING_SNAKE` | `const MAX_NOTES := 128` |
| Enums | `PascalCase` name, `SCREAMING_SNAKE` members | `enum Judgment { PERFECT, GREAT }` |
| Private | `_leading_underscore` | `var _internal: float` |

### Architecture

- **"Call down, signal up"**: Parents call child methods. Children emit signals. Siblings never reference each other — the parent wires them.
- **Composition over inheritance**: Build from small focused child nodes, not deep class hierarchies.
- **Autoloads**: Only for truly global, stateless services. Max 3: `Events` (signal bus), `MidiManager`, `Config`.
- **Signal bus**: `Events` autoload holds signals only — no methods, no state. Max 15 signals.

### Typing

Every variable, parameter, and return type must have a type hint. No exceptions.

```gdscript
# Always type everything
func calculate_score(judgment: Judgment, combo: int) -> int:
    return BASE_POINTS[judgment] * combo

# Cast @onready variables
@onready var _sprite := $Sprite2D as Sprite2D
```

### Rendering Strategy

- **`_draw()` for falling notes**: One node draws all visible notes via `draw_rect()`. Far fewer draw calls than hundreds of scene nodes.
- **Scene nodes for static elements**: Keyboard, UI, hit line — things that need interaction or inspector editing.
- **`_process(delta)` for rendering**: Use delta accumulation for song time. Position = `(note_time - current_time) * pixels_per_second`.
- **Object pooling**: Pool note objects if profiling shows instantiation is a bottleneck. Profile first.

### Input

- Event-driven (`_input` / `_unhandled_input`) for discrete actions (note hits, pause).
- Use `&"action_name"` (StringName) for input actions — pointer comparison, not string comparison.
- MIDI input goes through `MidiManager` autoload → emits signals on `Events` bus.

### Anti-Patterns to Avoid

- `get_node()` in `_process()` — cache with `@onready`
- `get_parent()` or `../../` paths — use `@export` or signals
- Untyped variables — always type
- God scripts (>200 lines doing multiple concerns) — split into child nodes
- String action names without `&""` — use StringName

---

## Python Pipeline Conventions

### Project Setup

- `uv` for dependency management. `pyproject.toml` with `[project.scripts]` entry point. Commit `uv.lock`.
- `src/` layout: `src/piano_prep/` package.
- `ruff` for linting.

### music21 Rules

- Parse one file at a time, `del score` + `gc.collect()` after extracting metadata. music21 is memory-heavy.
- Use `forceSource=True` to skip pickle caching (avoids 30K temp files during corpus indexing).
- Set 60-second timeout per file via `ProcessPoolExecutor`. Some files hang.
- Never use music21's built-in corpus system for our own corpus — build SQLite index instead.

### pianoplayer Rules

- Only run for on-demand song preparation, NOT during corpus indexing (too slow for batch).
- Wrap in try/except — it crashes on malformed scores. Non-fatal: produce JSON without fingering.
- `run_annotate()` writes to a temp XML file — parse output with music21, then clean up.

### SQLite Index

- FTS5 with external content table and porter tokenizer for search.
- Store `file_hash` (SHA256) for incremental re-indexing.
- `PRAGMA journal_mode=WAL` for concurrent read/write.
- Precompute top-20 similarity neighbors per song in `song_neighbors` table.

### Batch Processing

- `ProcessPoolExecutor` with `min(cpu_count(), 8)` workers. Each worker uses 200-500MB (music21 is heavy).
- Resumable: check file hash before processing, skip unchanged files.
- Never let one bad file stop the batch. Log failures, continue, report summary.
- Use `rich.progress.Progress` for progress bars.

### Testing

- `pytest` with real small .mxl fixtures in `tests/fixtures/`. Never mock music21 or pianoplayer.
- `@pytest.mark.slow` for pianoplayer tests (2-10s each).
- `tmp_path` for output files. Session-scoped fixtures for expensive parsing.

### Error Handling

- Validate file extension + size (<50MB) before parsing.
- Default missing metadata: title from filename, composer "Unknown", tempo 120 BPM.
- Skip scores with zero notes. Filter multi-part scores for piano by part name.

---

## Development Workflow

Milestone-based. Specs and plans live in `specs/` and `plans/`.

| File | Purpose |
|------|---------|
| `specs/ROADMAP.md` | What we're building, why, and the milestone sequence |
| `specs/current-milestone.md` | Active state — done, in progress, blockers |
| `specs/backlog.md` | Deferred ideas |
| Milestone spec | `specs/m{N}-{short-desc}.md` |
| Milestone plan | `plans/m{N}-{short-desc}-plan.md` |
| Godot conventions | `specs/GODOT_CONVENTIONS.md` |

### Session Start

```
1. Read specs/current-milestone.md     → what's done, what's next
2. Read active plan in plans/          → current task
3. Check open PRs (gh pr list)         → resume or start fresh
```

### Session End

Update `specs/current-milestone.md` with what was done, what's next, any blockers.
