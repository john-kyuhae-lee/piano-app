"""Tests for section boundary detection."""

from piano_prep.models import Note, Track
from piano_prep.sections import detect_sections


def test_rest_based_detection(simple_track):
    """Notes with a gap at beat 4 should create 2 sections."""
    sections = detect_sections([simple_track], (4, 4))
    assert len(sections) >= 2


def test_fallback_to_bars():
    """Continuous notes should produce sections via bar grouping."""
    track = Track(hand="right", notes=[
        Note(pitch=60, start_beat=float(i), duration_beats=1.0)
        for i in range(32)  # 32 beats = 8 bars = 2 sections at 4-bar chunks
    ])
    sections = detect_sections([track], (4, 4))
    assert len(sections) >= 2


def test_empty_track():
    sections = detect_sections([], (4, 4))
    assert len(sections) == 0


def test_single_note_track():
    track = Track(hand="right", notes=[
        Note(pitch=60, start_beat=0.0, duration_beats=1.0),
    ])
    sections = detect_sections([track], (4, 4))
    assert len(sections) >= 1


def test_labels_generated():
    track = Track(hand="right", notes=[
        Note(pitch=60, start_beat=float(i), duration_beats=1.0)
        for i in range(32)
    ])
    sections = detect_sections([track], (4, 4))
    for section in sections:
        assert section.label != ""
