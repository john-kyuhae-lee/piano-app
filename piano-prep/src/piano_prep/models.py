"""Data models for the song preparation pipeline."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class Note:
    """A single note in the game."""

    pitch: int  # MIDI pitch (21–108)
    start_beat: float  # Beat offset from song start
    duration_beats: float  # Duration in beats
    finger: int | None = None  # Fingering (1–5) or None


@dataclass
class Track:
    """A hand's worth of notes."""

    hand: str  # "right" or "left"
    notes: list[Note] = field(default_factory=list)


@dataclass
class Section:
    """A phrase boundary for practice chunking."""

    start_beat: float
    end_beat: float
    label: str  # "A", "B", "A'", etc.


@dataclass
class SongMeta:
    """Song metadata."""

    title: str
    composer: str
    difficulty: float  # 1.0–10.0
    tempo_bpm: int
    time_signature: tuple[int, int]  # (numerator, denominator)
    duration_seconds: float
    key: str


@dataclass
class Song:
    """Complete prepared song ready for the game."""

    meta: SongMeta
    sections: list[Section] = field(default_factory=list)
    tracks: list[Track] = field(default_factory=list)
