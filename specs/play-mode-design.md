# Play Mode Design — Adaptive Stepping

## Core Principle

**Tempo is rigid during play, adjusted between attempts.** The kid always plays against a steady metronome-like pulse. This builds internal rhythm and muscle memory. The tempo never warps mid-play.

## The Adaptive Stepping Algorithm

### Per-Section Flow

```
1. Kid selects a song → default to Learn Mode (wait mode) for first play
2. After Learn Mode completion → suggest Play Mode
3. Play Mode starts at 50% of marked tempo
4. Song plays section by section (4-bar chunks)

For each section:
  a) Play section at current fixed tempo
  b) Score accuracy:
     - GREEN (90%+): section passes
     - YELLOW (70-89%): section passes with note
     - RED (<70%): section fails → offer to retry at same tempo

  c) After all sections complete:
     - If all GREEN: bump tempo by 15% (e.g., 50% → 65% → 80% → 95% → 100%)
     - If any YELLOW: bump tempo by 10%
     - If any RED: stay at current tempo, highlight problem sections
     - Kid can also manually set tempo anytime

  d) Star thresholds (at current tempo):
     - 1 star: completed
     - 2 stars: 80%+ overall accuracy
     - 3 stars: 95%+ overall accuracy
     - Stars are awarded per tempo level — 3 stars at 50% ≠ 3 stars at 100%
     - Display shows "3 stars at 80% speed" vs "3 stars at full speed"
```

### Timing Windows (fixed, not tempo-dependent)

```
PERFECT:  ±50ms   — block at hit line, bright flash
GOOD:     ±150ms  — block near hit line, normal flash
OK:       ±300ms  — block approaching/past hit line, dim flash
MISS:     >300ms  — block fades past (Perform mode) or stays (Learn mode)

All three hit grades (Perfect/Good/OK) count as "correct" for accuracy.
Visual feedback intensity scales with grade — teaches timing subconsciously.
```

### Section Loop (Practice Tool)

```
During Play Mode, kid presses "Loop" button:
  1. Current 4-bar section highlights
  2. Section replays at current tempo on loop
  3. Speed buttons visible: [50%] [75%] [100%] [+] [-]
  4. Accuracy shown per loop attempt: "Try 1: 60% → Try 2: 75% → Try 3: 90%"
  5. "Got it!" button exits loop, continues song from next section
  6. Auto-suggest: if kid loops 5+ times at same speed with improving accuracy,
     suggest bumping speed up
```

### State Machine Extension

```
Current:  READY → PLAYING → COMPLETE
Proposed: READY → LEARN | PLAY | PERFORM → SECTION_RESULT → COMPLETE

LEARN:   Wait mode (existing). Blocks freeze at hit line.
PLAY:    Fixed tempo. Blocks fall continuously. Adaptive stepping between sections.
PERFORM: Full marked tempo. No stopping. Score on completion.
```

### What Happens on Miss (Play Mode)

The block does NOT freeze (that's Learn Mode). Instead:
- The block continues past the hit line and fades out over 0.5s
- A subtle "ghost" outline remains briefly showing what was missed
- Song keeps playing at the same steady tempo
- The kid's next note is still coming — they need to recover and keep going
- This teaches the critical real-world skill: recover from mistakes without stopping

### What Happens on Miss (Learn Mode)

Current behavior, unchanged:
- Block freezes at hit line
- Song time stops
- Kid presses correct key → block clears
- No time pressure, no penalty

## Duration Feedback (Future, Non-Blocking)

When eventually implemented:
- While kid holds a note, the cleared block fills with a lighter color
- If held for full duration: subtle sparkle/glow
- If released early: block just stops filling, no negative feedback
- Never blocking, never scored, purely visual encouragement

## Watch Mode (Pre-Play)

Before first play of a new piece:
- Blocks fall at 50% tempo, no input required
- Kid observes the note pattern, builds mental map (audiation)
- Plays through once automatically, then transitions to Learn Mode
- Optional — kid can skip to any mode

## Section Boundary Detection (M5 Pipeline)

During song preparation, identify phrase boundaries from:
1. Rests in the melody (natural pauses)
2. Time signature barline groups (every 4 bars as fallback)
3. Repeat signs and section markers from MusicXML
4. Fermatas and breath marks

Store as `sections` array in song JSON:
```json
{
  "sections": [
    {"start_beat": 0, "end_beat": 16, "label": "A"},
    {"start_beat": 16, "end_beat": 32, "label": "B"},
    {"start_beat": 32, "end_beat": 48, "label": "A'"}
  ]
}
```

## Target Milestone

M8 (Game Feel & Practice Mode) — but section boundaries should be added to the JSON schema in M5 (Song Pipeline).
