# Piano Hero — Design References & Research

## Open Source Projects

### Neothesia (Rust) — github.com/PolyMeilex/Neothesia
- GPU-instanced falling blocks via `WaterfallPipeline` — validates our `_draw()` approach
- **Glow effect does NOT require Vulkan/HDR** — rendered as separate additive-blend layer with alpha falloff. Implement as a second `_draw()` pass with slightly larger, semi-transparent rectangles behind active notes
- `piano-layout` crate computes key positions mathematically, not from textures — matches our approach
- Has wait mode (`PlayAlong`) but no scoring, no difficulty progression, no section practice

### PianoBooster (C++) — github.com/pianobooster/PianoBooster
- **Asymmetric scoring**: wrong notes penalized 5x harder than correct notes rewarded. Prevents button-mashing.
- **Chord tolerance by skill level**: skill < 3 accepts any one correct note in a chord; skill >= 3 requires ALL notes
- **Four modes**: Listen, Rhythm Tap, Follow You (wait mode), Play Along (fixed tempo) — maps to our Watch/Learn/Play/Perform
- **Proportional tempo adjustment**: `new_speed = current * (1.0 + increment)` — better than linear for musical feel
- **Timing in PPQN**: 15 PPQN early indicator, 0 PPQN stop point

### Midiano (JavaScript) — github.com/Bewelge/MIDIano
- **Time-to-space**: `height = (duration / noteToHeightConst) * (windowHeight - whiteKeyHeight)`
- Black key width = 58.3% of white key (matches our 60%)
- `noteDoneRatio` (0.0–1.0) for animating note clearing — clean pattern
- Measure lines behind waterfall for visual rhythm reference — add in M8
- Separate render passes for white-key notes and black-key notes

### Other Godot Projects
- `GodotGarden/piano-practice` — Godot 4 piano with timing variance, level progression
- `polyxord/g4rge` — Godot 4 rhythm game template
- `scenent/gd-rhythm` — Godot 4 falling note sample

---

## Pedagogical Frameworks

### Gordon's Music Learning Theory (Audiation)
- **Audiation** = hearing music in your mind when sound is not present. "Audiation is to music what thought is to language."
- **Skill sequence**: Aural/Oral → Verbal Association → Partial Synthesis → Symbolic Association → Composite Synthesis
- **Key principle**: experience music through listening/performing BEFORE notation/symbols
- **Watch Mode implication**: no finger numbers during Watch. Let kid absorb the motion pattern first, overlay fingering in Learn Mode
- **4-second pauses** between phrase sections during Watch Mode allow audiation to occur

### Dalcroze Eurhythmics
- Rhythm learned through physical movement against a steady pulse
- **Validates rigid tempo during play** — the pulse is sacred
- **Visual beat pulsing**: subtle brightness on hit line at each beat; measure lines that flash as beats pass
- Quick reaction exercises (future feature): brief tempo-change challenges after mastering steady pulse
- **Anti rubber-band**: Dalcroze validates that beat should be steady during active playing

### Csikszentmihalyi's Flow State
- Flow = challenge matches skill. Anxiety = too hard. Boredom = too easy.
- **Both skill and challenge must exceed a minimum threshold** — trivially easy doesn't produce flow
- **Jenova Chen's stair-step**: difficulty within a task increases, but initial difficulty of next task drops slightly. Creates recovery moments.
- **Player agency over difficulty** is more effective than system-controlled adjustment
- **Add tempo drop on consecutive failure**: 2+ RED sections → drop 5%. Sustained anxiety is worse than boredom for kids.

### Suzuki Method
- "Mother tongue" — immersion and listening before reading, like learning language
- **Listen first, then imitate** — validates Watch Mode
- **Revisit mastered pieces** — favorites/recently played should encourage replaying, not just push new songs
- **Non-judgmental environment** — mistakes are learning, not failure. No harsh punishment.

### Faber Piano Adventures
- 8 levels (Primer through 5), each with Lesson/Theory/Technique/Performance books
- **Stair-step progression**: within a unit difficulty increases, new unit starts slightly easier
- **Chunking**: pieces broken into practice segments
- **Difficulty calibration**: Primer=1-2, Level 1=2-3, Level 2=3-5, Level 3=5-7, Level 4-5=7-10

---

## Commercial App Lessons

### MuseFlow — "Never stop the music"
- AI generates exercises in real-time, adapts to player struggles
- Not applicable to our fixed-repertoire model, BUT:
- **Borrow**: offer simplified versions of hard sections as intermediate steps (algorithmically strip notes during M5 preparation)
- **Borrow**: minimize friction between attempts. After completing a section, immediately start the next.

### Piano Marvel — SASR Method
- See, Analyze, Sight-read, Repeat (adaptive difficulty test)
- **80% accuracy** as pass/fail threshold (well-tested at scale)
- **3-strike system**: 3 consecutive failures → test ends / lower difficulty
- Consider: if kid REDs the same section 3 times → auto-lower tempo + encourage

### Synthesia — Visual Clarity
- **Next-note highlight on virtual keyboard** — essential UX for beginners
- Block width exactly matches key width (no gaps)
- Hit line: single thin line, no decoration
- Clean dark background, no visual clutter during gameplay
- Finger numbers toggled, displayed as number on block

---

## Concrete Algorithms for M8

### Timing Windows
```
PERFECT:  ±50ms     Bright flash
GOOD:     ±150ms    Normal flash
OK:       ±300ms    Dim flash
MISS:     >300ms    Block fades (Play/Perform) or stays (Learn)
```
All hit grades count as "correct" for accuracy. Visual feedback teaches timing subconsciously.

### Scoring (Asymmetric, from PianoBooster)
```gdscript
const STEP_UP: float = 0.01      # Correct note reward
const STEP_DOWN: float = -0.05   # Wrong/miss penalty (5x)
var accuracy: float = 0.5        # Running, 0.0–1.0

Stars: 1 = completed, 2 = accuracy >= 0.80, 3 = accuracy >= 0.95
```

### Adaptive Tempo Stepping
```
All GREEN (90%+):     +15%
Mixed GREEN/YELLOW:   +10%
Any RED (<70%):        0% (retry)
2+ RED in a row:      -5% (back off — flow theory)
3 stars at 100%:      suggest harder piece

Formula: new_speed = current_speed * (1.0 + increment)
Clamped to [0.25, 1.50]
```

### Watch Mode Behavior
```
1. Play piece at 50% tempo
2. No finger numbers (Gordon: aural before symbolic)
3. 4-second pauses between phrase sections (audiation)
4. One pass through, then transition to Learn Mode
5. Kid can skip at any time
```

---

## Visual Enhancements Queue (M8)

1. **Next-note keyboard highlight** — glow on target key(s) in Learn Mode
2. **Beat pulse on hit line** — subtle brightness modulation at each beat
3. **Measure lines** behind waterfall for visual rhythm reference
4. **Fake glow on active notes** — additive-blend larger rect behind note (from Neothesia)
5. **Note clearing animation** — `noteDoneRatio` 0→1 with fade + scale
6. **Key press ripple** on virtual keyboard

---

## Anti-Patterns

1. **Rubber-band tempo** — never adjust tempo during play (Dalcroze, PianoBooster, all sources)
2. **Harsh miss punishment** — no buzzers, no game-over, no lives (Suzuki, flow theory)
3. **Hiding speed controls** — player agency > system control (Jenova Chen)
4. **Starting at full tempo** — always start at ≤50% (all pedagogical sources)
5. **Procedural exercise generation** — we have 10K+ real songs (Suzuki: real music > exercises)
6. **No back-off on failure** — must drop tempo on consecutive RED (flow theory)
7. **Showing everything at once** — Watch → Learn → Play is validated by Gordon's sequential stages
8. **Over-engineered scoring** — simple 5x asymmetric penalty is sufficient
