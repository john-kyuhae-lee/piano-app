# Piano Hero — Project Directives

A "Guitar Hero"-style piano learning app for kids, built with Godot Engine. Connects to a Yamaha P-125 via USB-MIDI. Falling blocks with classical fingering numbers (1-5) guide the player through songs loaded from MIDI/MusicXML files.

## Tech Stack

- **Engine**: Godot 4.x (GDScript)
- **MIDI**: Godot's built-in MIDI support (`InputEventMIDI`, `OS.get_connected_midi_inputs()`)
- **Song Format**: MusicXML (primary, has fingering data), MIDI (fallback)
- **Target Platform**: Linux laptop (Omarchy/Arch) connected to Yamaha P-125 via USB-MIDI
- **Graphics**: Godot 2D renderer (Compatibility mode for older hardware)

## Dev Commands

```bash
# Run from Godot editor
godot --path . --editor          # open editor
godot --path . --debug           # run game
godot --path .                   # run without debug overlay
```

## Project Structure

```
piano-app/
  project.godot                  # Godot project config
  scenes/                        # Scene files (.tscn)
    main.tscn                    # Entry point
    game/                        # Gameplay scenes
    ui/                          # Menus, song select, settings
  scripts/                       # GDScript files (.gd)
    midi/                        # MIDI input + file parsing
    engine/                      # Game loop, scoring, wait mode
    renderer/                    # Falling blocks, keyboard, effects
    fingering/                   # Fingering algorithm (Viterbi/DP)
  assets/                        # Fonts, textures, audio
  songs/                         # Song library (MusicXML / .mid files)
  specs/                         # Milestone specs
  plans/                         # Implementation plans
```

## Conventions

- GDScript style: snake_case for functions/variables, PascalCase for classes/nodes
- One script per scene node (Godot convention)
- Signals for decoupling modules (MIDI → Engine → Renderer)
- `@export` variables for inspector-tunable parameters
- Keep scenes shallow — compose with child scenes, not deep node trees

## Pre-PR Verification

```
[ ] Game runs without errors (godot --path . --debug)
[ ] No GDScript warnings (editor shows clean)
[ ] Test songs load and play correctly
[ ] MIDI input responds (if hardware-dependent PR)
```

## Development Workflow

Milestone-based development. Specs and plans live in `specs/` and `plans/`.

| File | Purpose |
|------|---------|
| `specs/ROADMAP.md` | What we're building and why |
| `specs/current-milestone.md` | Active state — done, in progress, blockers |
| `specs/backlog.md` | Deferred ideas |
| Milestone spec | `specs/m{N}-{short-desc}.md` |
| Milestone plan | `plans/m{N}-{short-desc}-plan.md` |
