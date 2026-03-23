"""Tests for MusicXML parser."""

from piano_prep.parser import parse_musicxml


def test_twinkle_has_one_track(twinkle_tracks):
    assert len(twinkle_tracks) == 1


def test_twinkle_is_right_hand(twinkle_tracks):
    assert twinkle_tracks[0].hand == "right"


def test_twinkle_has_14_notes(twinkle_tracks):
    assert len(twinkle_tracks[0].notes) == 14


def test_twinkle_first_note_is_c4(twinkle_tracks):
    assert twinkle_tracks[0].notes[0].pitch == 60


def test_twinkle_notes_sorted_by_beat(twinkle_tracks):
    notes = twinkle_tracks[0].notes
    for i in range(len(notes) - 1):
        assert notes[i].start_beat <= notes[i + 1].start_beat


def test_ode_has_notes(ode_tracks):
    total = sum(len(t.notes) for t in ode_tracks)
    assert total > 0


def test_ode_has_15_notes(ode_tracks):
    assert len(ode_tracks[0].notes) == 15
