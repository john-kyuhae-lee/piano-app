"""Tests for JSON writer."""

import json
from pathlib import Path

from piano_prep.models import Note, Section, Song, SongMeta, Track
from piano_prep.writer import write_song_json


def test_round_trip(tmp_path, simple_track, simple_meta):
    """Write a song and read it back."""
    song = Song(
        meta=simple_meta,
        sections=[Section(start_beat=0.0, end_beat=8.0, label="A")],
        tracks=[simple_track],
    )
    output = tmp_path / "test.json"
    write_song_json(song, output)

    assert output.exists()
    data = json.loads(output.read_text())

    assert data["meta"]["title"] == "Test"
    assert data["meta"]["tempo_bpm"] == 120
    assert len(data["tracks"]) == 1
    assert len(data["tracks"][0]["notes"]) == 4
    assert len(data["sections"]) == 1


def test_note_fields(tmp_path, simple_meta):
    """Verify note JSON has all required fields."""
    track = Track(hand="right", notes=[
        Note(pitch=60, start_beat=0.0, duration_beats=1.0, finger=1),
    ])
    song = Song(meta=simple_meta, tracks=[track])
    output = tmp_path / "test.json"
    write_song_json(song, output)

    data = json.loads(output.read_text())
    note = data["tracks"][0]["notes"][0]
    assert "pitch" in note
    assert "start_beat" in note
    assert "duration_beats" in note
    assert "finger" in note
    assert note["finger"] == 1


def test_null_finger(tmp_path, simple_meta):
    """Finger=None should serialize as null."""
    track = Track(hand="right", notes=[
        Note(pitch=60, start_beat=0.0, duration_beats=1.0, finger=None),
    ])
    song = Song(meta=simple_meta, tracks=[track])
    output = tmp_path / "test.json"
    write_song_json(song, output)

    data = json.loads(output.read_text())
    assert data["tracks"][0]["notes"][0]["finger"] is None
