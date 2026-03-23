"""Shared test fixtures for piano-prep."""

from __future__ import annotations

from pathlib import Path

import pytest

from piano_prep.models import Note, Section, Song, SongMeta, Track
from piano_prep.parser import parse_musicxml

FIXTURES = Path(__file__).parent / "fixtures"


@pytest.fixture(scope="session")
def twinkle_path() -> Path:
    return FIXTURES / "twinkle.mxl"


@pytest.fixture(scope="session")
def ode_path() -> Path:
    return FIXTURES / "ode_to_joy.mxl"


@pytest.fixture(scope="session")
def twinkle_tracks(twinkle_path: Path) -> list[Track]:
    return parse_musicxml(twinkle_path)


@pytest.fixture(scope="session")
def ode_tracks(ode_path: Path) -> list[Track]:
    return parse_musicxml(ode_path)


@pytest.fixture
def simple_track() -> Track:
    """Synthetic track for fast tests without music21."""
    return Track(hand="right", notes=[
        Note(pitch=60, start_beat=0.0, duration_beats=1.0),
        Note(pitch=62, start_beat=1.0, duration_beats=1.0),
        Note(pitch=64, start_beat=2.0, duration_beats=2.0),
        Note(pitch=60, start_beat=5.0, duration_beats=1.0),
    ])


@pytest.fixture
def simple_meta() -> SongMeta:
    return SongMeta(
        title="Test", composer="Test", difficulty=3.0,
        tempo_bpm=120, time_signature=(4, 4),
        duration_seconds=10.0, key="C major",
    )
