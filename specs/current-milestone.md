# Current Milestone

## Active: M1 — Proof of Life

**Status**: Complete

**Goal**: Godot window with a virtual piano keyboard at the bottom and colored blocks falling from the top. Hardcoded 8-bar melody (C major scale, both hands). No MIDI, no file loading. Pure rendering proof.

**Done**:
- Project scaffolding (repo, CLAUDE.md, specs)
- Roadmap v2 (8 milestones — kid-driven discovery model with PDMX corpus + recommendations)
- Technical research (Godot MIDI, rendering, fingering algorithms, P-125 compatibility, song sources)
- Godot 4.6.1 installed (Compatibility renderer confirmed on Intel Iris 6100)
- M1 spec (`specs/m1-proof-of-life.md`)
- M1 plan (`plans/m1-proof-of-life-plan.md`)
- M1 implementation:
  - `project.godot` — Compatibility renderer, 1920×1080
  - `scripts/game/keyboard.gd` — 88-key piano keyboard via `_draw()`
  - `scripts/game/note_renderer.gd` — falling blocks via single `_draw()`, looping demo
  - `scripts/game/main.gd` — composes keyboard + renderer
  - `scenes/main.tscn` — entry point scene
- Verified: runs clean, no errors, no warnings

**Blockers**: None

**Next**:
- Visual review — run and confirm keyboard layout + falling blocks look correct
- Commit M1
- Begin M2 spec (MIDI input from Yamaha P-125)
