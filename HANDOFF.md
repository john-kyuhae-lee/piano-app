# Piano Hero — Workstation Setup & Handoff

## Context

You are continuing development of Piano Hero, a Guitar Hero-style piano learning app built with Godot Engine. The project repo is at `github.com/john-kyuhae-lee/piano-app`. All specs, plans, conventions, and directives are in the repo — read them.

This is a fresh Omarchy (Arch Linux) install on a 2015 MacBook Pro 13" (MacBookPro12,1). This machine will be both the development workstation AND the eventual kiosk target (M8).

## Step 1: Clone the repo

```bash
gh auth login
git clone git@github.com:john-kyuhae-lee/piano-app.git ~/piano-app
cd ~/piano-app
```

## Step 2: Read the project

Read these files in order — they contain everything about the project:
1. `CLAUDE.md` — project directives, tech stack, coding conventions (GDScript + Python)
2. `specs/ROADMAP.md` — 8-milestone roadmap, architecture, content strategy
3. `specs/current-milestone.md` — where we left off
4. `specs/GODOT_CONVENTIONS.md` — full Godot/GDScript reference (995 lines)

## Step 3: Install development tools

This machine needs:

```bash
# Godot 4.3+ (check AUR for latest)
yay -S godot

# Python 3.10+ (should be installed, verify)
python --version

# uv (Python package manager)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Verify
godot --version
uv --version
```

## Step 4: Set up Claude Code permissions

Create `.claude/settings.local.json` in the project root (or globally at `~/.claude/settings.local.json`):

```json
{
  "permissions": {
    "allow": [
      "Bash(*)",
      "Read(*)",
      "Write(*)",
      "Edit(*)",
      "Glob(*)",
      "Grep(*)",
      "WebSearch",
      "WebFetch(*)",
      "Agent(*)"
    ],
    "deny": [
      "Bash(git push --force *)",
      "Bash(rm -rf /)",
      "Bash(git reset --hard *)"
    ]
  }
}
```

## Hardware Facts

- **Machine**: 2015 MacBook Pro 13" (Intel Iris 6100 GPU)
- **GPU limitation**: NO Vulkan support. OpenGL 4.1 only.
- **Godot renderer**: Must use **Compatibility** renderer (not Forward+ or Mobile). No HDR glow — use fake glow fallback (alpha pulsing + additive blend).
- **Wi-Fi**: Broadcom BCM4360 — may need `broadcom-wl` driver if not working (`yay -S broadcom-wl`)
- **Yamaha P-125**: Will be connected via USB-B to USB-A cable. Class-compliant USB-MIDI, no drivers needed. Shows up via ALSA. Not connected yet — not needed until M2.

## Where We Left Off

- M1 (Proof of Life) is the active milestone — not started yet
- Roadmap is complete (8 milestones)
- Agent directives are complete (CLAUDE.md + GODOT_CONVENTIONS.md)
- Next step: write M1 spec and plan, then implement

## Key Architecture Decisions Already Made

1. **Compatibility renderer** (not Forward+) — no Vulkan on this hardware
2. **`_draw()` for falling notes** — one node draws all notes, not individual scene nodes
3. **Two tools**: Godot game + Python CLI (`piano-prep`) with JSON as the contract
4. **PDMX dataset** (250K+ MusicXML) filtered to piano-solo for the corpus
5. **SQLite FTS5** for local search index
6. **`pianoplayer`** (Python) for fingering computation, run lazily on first play
7. **Content-based recommendations** — precomputed similarity on difficulty/key/tempo/composer/era
8. **Wait mode** as the core gameplay — blocks pause until correct note is played
