"""Extract song metadata and compute difficulty from music21 scores."""

from __future__ import annotations

import gc
from pathlib import Path

import music21

from .models import SongMeta, Track


def extract_metadata(path: Path, tracks: list[Track]) -> SongMeta:
    """Extract metadata from a MusicXML file and compute difficulty."""
    score = music21.converter.parse(str(path), forceSource=True)

    try:
        meta = _build_metadata(score, path, tracks)
    finally:
        del score
        gc.collect()

    return meta


def _build_metadata(
    score: music21.stream.Score, path: Path, tracks: list[Track]
) -> SongMeta:
    """Build SongMeta from a parsed score."""
    # Title
    title = score.metadata.title if score.metadata and score.metadata.title else path.stem
    title = title.strip()

    # Composer
    composer = "Unknown"
    if score.metadata:
        for attr in ("composer", "creator"):
            val = getattr(score.metadata, attr, None)
            if val:
                composer = str(val).strip()
                break

    # Key
    key_str = "Unknown"
    key_analysis = score.analyze("key")
    if key_analysis:
        key_str = str(key_analysis)

    # Tempo
    tempo_bpm = 120  # default
    for mm in score.flatten().getElementsByClass(music21.tempo.MetronomeMark):
        if mm.number is not None:
            tempo_bpm = int(mm.number)
            break

    # Time signature
    time_sig = (4, 4)  # default
    for ts in score.flatten().getElementsByClass(music21.meter.TimeSignature):
        time_sig = (ts.numerator, ts.denominator)
        break

    # Duration
    duration_seconds = float(score.duration.quarterLength) * (60.0 / tempo_bpm)

    # Difficulty
    difficulty = _compute_difficulty(tracks, tempo_bpm, duration_seconds)

    return SongMeta(
        title=title,
        composer=composer,
        difficulty=round(difficulty, 1),
        tempo_bpm=tempo_bpm,
        time_signature=time_sig,
        duration_seconds=round(duration_seconds, 1),
        key=key_str,
    )


def _compute_difficulty(tracks: list[Track], tempo_bpm: int, duration_seconds: float) -> float:
    """Compute difficulty on a 1–10 scale from note features."""
    all_notes = [n for t in tracks for n in t.notes]
    if not all_notes:
        return 1.0

    # Note density (notes per second)
    density = len(all_notes) / max(duration_seconds, 1.0)
    density_score = min(density / 5.0, 1.0)  # 5 nps = max

    # Ambitus (pitch range)
    pitches = [n.pitch for n in all_notes]
    ambitus = max(pitches) - min(pitches)
    ambitus_score = min(ambitus / 48.0, 1.0)  # 4 octaves = max

    # Rhythmic complexity (variety of note durations)
    durations = set(round(n.duration_beats, 3) for n in all_notes)
    rhythm_score = min(len(durations) / 6.0, 1.0)  # 6 different durations = max

    # Tempo factor
    tempo_score = min(tempo_bpm / 160.0, 1.0)  # 160 BPM = max

    # Both hands penalty
    hand_count = len(tracks)
    hand_score = 0.5 if hand_count >= 2 else 0.0

    # Weighted combination
    difficulty = (
        density_score * 3.0
        + ambitus_score * 1.5
        + rhythm_score * 1.5
        + tempo_score * 2.0
        + hand_score * 2.0
    ) / 10.0 * 9.0 + 1.0  # Scale to 1–10

    return min(max(difficulty, 1.0), 10.0)
