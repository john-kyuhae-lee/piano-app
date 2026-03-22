# Current Milestone

## Active: M3 — First Playable

**Status**: Complete — needs playtesting with Yamaha P-125

**Goal**: Falling blocks + MIDI input + wait mode. The kid plays along at their own pace — blocks pause at the hit line until the correct key is pressed.

**Done**:
- M1 complete (rendering proof)
- M2 complete (MIDI input verified with Yamaha P-125)
- Game signals on Events bus (note_cleared, wrong_note_played, song_completed, game_state_changed)
- GameEngine with wait mode, state machine (Ready → Playing → Complete), hit detection
- NoteRenderer refactored — driven by GameEngine, visual feedback (white flash on clear, red flash on wrong)
- Main scene wiring — state labels ("Press any key to start", "Song Complete!")
- Song: Twinkle Twinkle Little Star, right hand only, 100 BPM

**Blockers**: None

**Next**:
- Playtest with Yamaha P-125 — verify feel, latency, correctness
- Begin M4 spec (Song Pipeline & Fingering)
