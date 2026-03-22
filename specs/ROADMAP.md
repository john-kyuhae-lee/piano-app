# Piano Hero — Roadmap

## Vision

A dedicated "Piano Hero" app that makes piano practice feel like a game. Falling blocks with finger numbers guide the player through songs. The kid has full freedom to explore, search, and discover music — the app builds a personalized library based on what they love. Connects to a Yamaha P-125 via USB-MIDI. Runs as a kiosk on a dedicated laptop sitting on the piano.

## Target Users

- **Player (Kid)**: Full autonomy. Searches for songs, picks what they want, plays at their own pace, discovers similar songs. The app feels like theirs — not something Dad set up for them.
- **Admin (Dad)**: Initial setup, hardware, deploys updates. Stays out of the kid's way once it's running.

## Architecture

```
Song Corpus (offline, pre-indexed)         Game Runtime (Godot 4.x)
──────────────────────────────────         ────────────────────────
PDMX dataset (250K+ MusicXML scores)      Search UI → kid browses/searches
  → filter: piano solo/easy piano          Song card → auto-prepares on first play
  → extract metadata (music21)             Renders falling blocks + finger numbers
  → compute difficulty features            Listens for USB-MIDI input
  → build SQLite index                     Wait mode / scoring / effects
  → store: corpus/*.mxl                    Recommends similar songs

Song Preparation (Python, runs on-demand)
─────────────────────────────────────────
Triggered on first play of a new song:
  MusicXML → music21 parse
  → pianoplayer (fingering)
  → normalize to game JSON
  → cache: prepared/*.json
```

Three layers, clean boundaries:
1. **Corpus** — the raw library with search index. Built once, updated occasionally by Dad.
2. **Preparation** — converts a specific song to game-ready JSON with fingering. Runs lazily on first play, result is cached. Takes a few seconds.
3. **Game** — loads prepared JSON, renders, handles input. Never touches MusicXML or computes fingering.

## Hardware

- **Dev machine**: Beelink (Arch Linux / Omarchy) — build and test here
- **Target machine**: ~2016 MacBook running Omarchy — kiosk mode, sits on the piano
- **Instrument**: Yamaha P-125 via USB-B to USB-A cable (class-compliant USB-MIDI, no drivers needed)

## Renderer Decision

Glow/neon effects require Forward+ or Mobile renderer (Vulkan). The 2016 MacBook _may_ support Vulkan via Intel Iris. We design for Forward+ but build a Compatibility fallback (flat colors, no bloom) and test on the target hardware in M2.

## Song Sources

| Source | Format | Size | License | Notes |
|--------|--------|------|---------|-------|
| **PDMX** | MusicXML, MIDI | 250K+ scores | CC-BY | Primary corpus. Scraped from MuseScore, on Zenodo |
| **music21 corpus** | MusicXML, kern | 3K+ works | BSD | Built into Python lib. Great for testing |
| **Mutopia Project** | LilyPond, MIDI | 2,100+ pieces | CC/PD | Classical MIDI files |
| **OpenScore Lieder** | mscx → MusicXML | 1,300 songs | CC0 | Art songs, convertible |

MuseScore's API is dead (shut down after Muse Group acquisition). We don't need it — PDMX already has the data as a downloadable corpus.

## Recommendation Engine

No ML required. Content-based similarity using features music21 can compute:

| Feature | Source | Similarity Metric |
|---------|--------|-------------------|
| Difficulty | note density, range (ambitus), rhythmic complexity | Euclidean distance |
| Key | key signature analysis | Circle-of-fifths distance |
| Tempo | BPM from tempo markings | Absolute difference |
| Composer | metadata field | Exact match |
| Era | inferred from composer dates | Same/adjacent period |
| Instrument | part names in MusicXML | Filter: piano only |

"If you liked Für Elise, try these" = same difficulty range + same era + similar key + similar tempo. Weighted KNN on the feature vector, top 5-10 results.

---

## Milestones

### M1 — Proof of Life

**Goal**: A Godot window with a piano keyboard at the bottom and colored blocks falling from the top. Hardcoded 8-bar melody. No MIDI, no file loading. Pure rendering proof.

**What the kid sees**: Blocks falling onto a piano. Nothing interactive yet, but it looks like a game.

**Deliverables**:
- Godot project scaffolding (Forward+ renderer, 1920x1080)
- Virtual piano keyboard (88 keys, correct white/black layout, bottom of screen)
- Falling block renderer (blocks fall at constant speed, width matches target key, length = note duration)
- Left hand (blue) / Right hand (green) color coding
- Hit line (horizontal line above keyboard where notes should be played)
- Hardcoded note sequence: C major scale ascending + descending, both hands
- Time-to-pixel positioning (notes positioned by time offset, not incremental movement)

**Technical notes**:
- `_process(delta)` for rendering, accumulate delta for song time
- Position = `(note_time - current_time) * pixels_per_second` (no drift)
- Each note is a scene instance (Node2D + ColorRect)
- Test at 60fps — verify no stuttering with 20+ simultaneous blocks

---

### M2 — The Piano Talks Back

**Goal**: Connect to the Yamaha P-125 via USB-MIDI. When a key is pressed on the real piano, the corresponding virtual key lights up on screen.

**What the kid sees**: Press a piano key, the screen reacts instantly.

**Deliverables**:
- MIDI input manager (Autoload singleton)
  - `OS.open_midi_inputs()` on ready
  - Handle `InputEventMIDI` for Note On/Off
  - Emit signals: `note_on(pitch, velocity)`, `note_off(pitch)`
- Virtual keyboard responds to MIDI input (key lights up on press, dims on release)
- Visual feedback: pressed keys change color + subtle highlight
- Latency test: measure round-trip time (MIDI event → visual update), target <16ms (one frame)
- Device connection UI: show connected device name, handle disconnect/reconnect
- **Renderer test on target hardware**: Export and run on the 2016 MacBook. Does Forward+ work? If not, document and plan Compatibility fallback.

**Technical notes**:
- Require Godot 4.3+ (fix for simultaneous MIDI event dropping, PR #90485)
- P-125 sends Note On (velocity 1-127), Note Off (velocity 64 fixed), CC 64 (sustain pedal)
- Note range: A0-C8 (MIDI 21-108)
- Signal architecture: MidiManager (Autoload) → emits signals → Keyboard scene connects

---

### M3 — First Playable

**Goal**: Combine M1 + M2 into the first playable experience. Falling blocks + MIDI input + wait mode. The kid can play along at their own pace.

**What the kid sees**: Blocks fall toward the piano. When a block reaches the line, it stops and waits. Press the right key, block clears, next block continues. It's a game now.

**Deliverables**:
- Game engine (core loop):
  - Song timeline advances based on correct input (wait mode)
  - Compare incoming MIDI pitch against expected note
  - On correct note: advance timeline, clear/flash the block, continue
  - On wrong note: visual feedback (block shakes or turns red briefly)
  - On no input: blocks pause at the hit line (no time pressure)
- Integrate with M1 renderer and M2 MIDI input
- Hardcoded song: "Twinkle Twinkle Little Star" (right hand only, simple)
- Basic state machine: Ready → Playing → Song Complete
- Song complete screen: simple celebration (kid-friendly)

**Technical notes**:
- Wait mode means `song_time` only advances when correct note is played
- Handle chords (multiple simultaneous notes) — all notes in the chord must be pressed
- Tolerance window: accept note slightly before/after the hit line (configurable, start with ±200ms)

---

### M4 — Debug Observability

**Goal**: Automated testing and visual inspection loop. The AI agent (Claude Code) can launch the game, interact with it, and observe results through structured telemetry and strategic screenshots — without manual human involvement.

**What Dad sees**: Nothing — this is invisible infrastructure. The game works the same. But the AI building it can now self-test every change.

**Deliverables**:
- Structured telemetry logger (JSONL): frame, song_time, state, events, FPS, input-to-response deltas
- Viewport screenshot capture on state transitions (Ready, Playing, first clear, Complete)
- Computer keyboard → MIDI mapping for testing without physical piano
- Test harness shell script: launch game, send ydotool keypresses, collect telemetry + screenshots
- All debug features gated behind `--telemetry` / `--capture` user args (zero cost in normal play)

**Technical notes**:
- Telemetry connects to Events bus signals — no coupling to game logic
- Screenshots via `get_viewport().get_texture().get_image().save_png()` — captures viewport directly, no compositor race conditions
- `ydotool` for kernel-level input injection (works with Wayland/Godot unlike `wtype`)
- Three observation layers: telemetry (timing/state), screenshots (visual), video (occasional, via `--write-movie`)

---

### M5 — Song Pipeline & Fingering

**Goal**: Build the automated song preparation pipeline. MusicXML in, game-ready JSON with fingering out. Test with real songs the kid wants to play.

**What the kid sees**: Real songs appear and each block has a finger number (1-5). They're learning proper technique while playing.

**Deliverables**:
- **Song JSON format** (the contract between pipeline and game):
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
    "tracks": [
      {
        "hand": "right",
        "notes": [
          {"pitch": 76, "start_beat": 0.0, "duration_beats": 0.5, "finger": 4},
          ...
        ]
      }
    ]
  }
  ```
- **Python preparation tool** (`piano-prep`):
  - Input: .mxl/.xml (MusicXML) or .mid (MIDI)
  - Parse with `music21`
  - Compute fingering with `pianoplayer`
  - Split left/right hand tracks
  - Compute difficulty features (note density, ambitus, rhythmic complexity)
  - Output: `prepared/{song_id}.json`
- **Godot song loader**: reads prepared JSON, creates note sequence
- **Finger number rendering**: large bold number on each block, white on colored background
- **Test with 5 real songs**:
  - Twinkle Twinkle Little Star (beginner)
  - Ode to Joy (beginner)
  - Für Elise opening (intermediate, right hand)
  - A piece from the kid's current lesson book
  - One song the kid specifically asks for

**Technical notes**:
- `music21` for MusicXML parsing, `pianoplayer` for fingering, `mido` for raw MIDI
- MIDI hand splitting heuristic: track 1 = right, track 2 = left; fallback: split at middle C
- `pianoplayer` accepts MusicXML/MIDI, outputs fingering per note
- Preparation takes 2-10 seconds per song — fast enough for on-demand use
- Difficulty: normalized 1-10 scale from weighted features

---

### M6 — Song Library & Search

**Goal**: The kid has a massive library of songs and can search, browse, and pick whatever they want. No waiting for Dad.

**What the kid sees**: A search bar and a grid of songs. Type "beethoven" or "star wars" and songs appear. Pick one and play.

**Deliverables**:
- **Corpus builder** (Python, runs once on setup):
  - Download PDMX dataset (or curated piano subset) from Zenodo
  - Filter for piano solo / easy piano arrangements
  - Extract metadata for each score using music21: title, composer, key, tempo, difficulty features, duration estimate
  - Build SQLite index: one row per song with metadata + path to source .mxl
  - Estimate: 10K-30K piano pieces after filtering from 250K total
- **Search UI in Godot**:
  - Search bar (title and/or composer)
  - Results grid: large cards with title, composer, difficulty stars (1-5)
  - Sort by: difficulty, composer, title
  - Filter by: difficulty range, hand (right only / left only / both)
  - Kid-friendly: big text, big buttons, minimal typing (on-screen keyboard or physical)
- **Lazy preparation**: when kid picks a song for the first time:
  - Show "Preparing your song..." with a progress indicator
  - Run `piano-prep` in background (2-10 seconds)
  - Cache result in `prepared/` — instant on second play
- **Song detail screen**: before playing, show title, composer, difficulty, duration, hands required
- **Favorites**: kid can star songs they like (persisted locally)
- **Recently played**: track play history for quick access

**Technical notes**:
- SQLite for the index — Godot can call Python via `OS.execute()` or we embed a SQLite GDExtension
- PDMX is ~50GB for 250K scores. Piano-only subset will be much smaller (~2-5GB of .mxl files)
- Search: SQLite FTS5 (full-text search) on title + composer
- Difficulty stars: map computed difficulty (1-10 float) to 1-5 stars for display
- The corpus lives on disk, not in memory. Godot only loads the SQLite index.

---

### M7 — Discovery & Recommendations

**Goal**: The app actively helps the kid discover new music. "You liked this? Try these." The library grows with the kid's interests.

**What the kid sees**: After finishing a song, 5-10 suggestions appear. "Songs like this one." They tap one and keep exploring. The app feels alive — it knows what they like.

**Deliverables**:
- **Recommendation engine** (Python service or precomputed):
  - Content-based similarity using music21-computed features:
    - Difficulty (note density, ambitus, rhythmic complexity)
    - Key (circle-of-fifths distance)
    - Tempo (BPM difference)
    - Composer (same composer bonus)
    - Era (Baroque/Classical/Romantic/Modern — inferred from composer dates)
  - Weighted KNN on normalized feature vectors, return top 5-10
  - Precompute similarity matrix for the corpus (offline, stored in SQLite)
- **"Songs like this" screen**: appears after song completion or accessible from song detail
  - Grid of recommended songs with difficulty comparison ("slightly harder", "similar difficulty")
  - "Same composer" section
  - "Try something new" section (different era/style at same difficulty)
- **Difficulty progression**:
  - Track kid's accuracy over time
  - Gently suggest slightly harder pieces when accuracy is consistently high
  - "Ready for a challenge?" prompt (not pushy — the kid controls their journey)
- **Collections / playlists**:
  - Auto-generated: "Your Favorites", "Recently Played", "Suggested For You"
  - Kid can create named playlists (e.g., "Recital Pieces", "Fun Ones")
- **Play history & stats** (for the kid, not Dad):
  - Songs played, time practiced, accuracy trends
  - Not gamified — informational, encouraging
  - "You've played 12 different songs this week!"

**Technical notes**:
- Precompute feature vectors for all songs in the corpus during indexing (M5 corpus builder)
- Similarity: cosine similarity on normalized [difficulty, key_fifths, tempo_norm, era_ordinal] vector
- Same-composer and same-era bonuses as additive weights
- Store precomputed top-20 neighbors per song in SQLite (avoids runtime computation)
- Play history: local JSON or SQLite in Godot's `user://` directory

---

### M8 — Game Feel & Practice Mode

**Goal**: Polish the core gameplay and add practice features. This is where it goes from "working prototype" to "something the kid wants to use every day."

**What the kid sees**: The game feels alive. Glowing effects, satisfying feedback, stars earned. Practice tools to master hard sections.

**Deliverables**:
- **Visual polish**:
  - Glow effect on correct hits (Forward+ HDR bloom, or fake glow fallback)
  - Smooth block-clearing animation (fade + scale, not instant disappear)
  - Key press ripple effect on virtual keyboard
  - Background: subtle gradient or gentle animated particles (not distracting)
- **Audio feedback** (from laptop speakers, not piano):
  - Correct note: subtle chime or sparkle
  - Wrong note: gentle buzz (not punishing)
  - Song complete: celebratory jingle
  - Streak sound: escalating chime when hitting consecutive correct notes
- **Scoring**:
  - Stars per song (1-3 based on accuracy)
  - Personal best tracking per song
  - No competitive elements — this is practice, not competition
- **Practice mode tools**:
  - Loop a section (kid or Dad sets start/end measure markers)
  - Slow down (half speed, quarter speed — blocks fall slower)
  - Right hand only / Left hand only / Both hands
  - "Watch mode": blocks fall at tempo without waiting, kid observes the pattern first
- **Speed control**: adjustable falling speed (affects read-ahead time, not song tempo)

**Technical notes**:
- Glow: WorldEnvironment + HDR 2D + Forward+/Mobile renderer
- Fallback if Compatibility: modulate alpha pulsing + additive blend for fake glow
- Audio: Godot AudioStreamPlayer, preload short samples
- Save data: JSON in `user://` directory
- Practice loop: store measure boundaries in song JSON, slice the note array

---

### M9 — Kiosk & Deploy

**Goal**: The app runs on the dedicated MacBook as a kiosk. Power on → Piano Hero. No desktop, no distractions. Like a Nintendo.

**What the kid sees**: The laptop turns on and the game is just there.

**Deliverables**:
- **Omarchy installation** on ~2016 MacBook (Intel)
  - Wi-Fi workaround: USB tethering from phone for initial setup
  - Install Godot runtime dependencies
  - Copy corpus + prepared songs
- **Godot export**: Linux x86_64 binary, tested on target hardware
- **Hyprland kiosk config**:
  - `exec-once = /path/to/piano-hero`
  - No taskbar, no app switcher (kid-proof)
  - Disable screen lock, disable sleep when plugged in
- **Auto-start on boot**: systemd user service or Hyprland exec-once
- **Admin mode**: keyboard shortcut (Ctrl+Shift+A) to exit kiosk → terminal for Dad:
  - Update corpus (download new PDMX release, re-index)
  - Adjust settings (difficulty range, volume, speed defaults)
  - Update the app binary
  - Add custom songs manually
- **Graceful USB handling**:
  - Detect P-125 connect/disconnect
  - "Plug in your piano!" screen when disconnected
  - Auto-reconnect when plugged back in
- **Power management**: dim screen after inactivity, wake on MIDI input or keypress
- **Crash recovery**: if app crashes, auto-restart via systemd

---

## Non-Goals (Entire Project)

- Sound generation (the Yamaha produces all audio)
- Recording/playback of performances
- Online/cloud features (everything is local and offline)
- OMR (scanning paper sheet music with camera)
- Multi-player / competitive modes
- Mobile/tablet port (laptop only)
- Teaching music theory (this is a practice tool, not a tutor)
- Real-time internet search (the corpus is pre-downloaded)
- Copyrighted music (PDMX is public domain only — but that includes all of classical music, which is plenty)

## Content Strategy

The corpus is pre-downloaded and local. No internet needed at runtime.

**Initial library**: PDMX piano-solo subset (~10K-30K pieces). Includes virtually all classical piano repertoire that's been digitized on MuseScore. This covers:
- All the "greatest hits" (Für Elise, Moonlight Sonata, Turkish March, etc.)
- Simplified arrangements for beginners
- Graded repertoire (ABRSM, RCM exam pieces)
- Pop/movie transcriptions that are public domain arrangements

**Growth model**: The library doesn't grow from downloads — it grows from the kid _discovering_ what's already there. 10K+ songs is more than anyone can play in a lifetime. The recommendation engine surfaces relevant pieces the kid wouldn't have found by searching.

**Custom songs**: Dad can add songs from any source (MuseScore manual download, kid's teacher provides a file, etc.) by dropping .mxl/.mid files into the corpus directory and re-indexing.
