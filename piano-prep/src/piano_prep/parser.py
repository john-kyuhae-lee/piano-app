"""Parse MusicXML files into internal Note/Track models using music21."""

from __future__ import annotations

import gc
from pathlib import Path

import music21

from .models import Note, Track


def parse_musicxml(path: Path) -> list[Track]:
    """Parse a MusicXML file and return left/right hand tracks."""
    score = music21.converter.parse(str(path), forceSource=True)

    try:
        tracks = _extract_tracks(score)
    finally:
        del score
        gc.collect()

    return tracks


def _extract_tracks(score: music21.stream.Score) -> list[Track]:
    """Extract note data from a music21 Score, split by hand."""
    parts = list(score.parts)

    if len(parts) == 0:
        return []

    if len(parts) == 1:
        # Single part — split by pitch at middle C (MIDI 60)
        return _split_single_part(parts[0])

    # Multiple parts — first = right hand, second = left hand
    right = _extract_notes_from_part(parts[0], "right")
    left = _extract_notes_from_part(parts[1], "left")
    return [t for t in [right, left] if t.notes]


def _extract_notes_from_part(part: music21.stream.Part, hand: str) -> Track:
    """Extract notes from a single music21 Part."""
    notes: list[Note] = []

    for element in part.flatten().notesAndRests:
        if isinstance(element, music21.note.Note):
            notes.append(Note(
                pitch=element.pitch.midi,
                start_beat=float(element.offset),
                duration_beats=float(element.quarterLength),
            ))
        elif isinstance(element, music21.chord.Chord):
            for pitch in element.pitches:
                notes.append(Note(
                    pitch=pitch.midi,
                    start_beat=float(element.offset),
                    duration_beats=float(element.quarterLength),
                ))

    notes.sort(key=lambda n: (n.start_beat, n.pitch))
    return Track(hand=hand, notes=notes)


def _split_single_part(part: music21.stream.Part) -> list[Track]:
    """Split a single part into right/left by pitch (middle C = 60)."""
    right_notes: list[Note] = []
    left_notes: list[Note] = []

    for element in part.flatten().notesAndRests:
        if isinstance(element, music21.note.Note):
            note = Note(
                pitch=element.pitch.midi,
                start_beat=float(element.offset),
                duration_beats=float(element.quarterLength),
            )
            if element.pitch.midi >= 60:
                right_notes.append(note)
            else:
                left_notes.append(note)
        elif isinstance(element, music21.chord.Chord):
            for pitch in element.pitches:
                note = Note(
                    pitch=pitch.midi,
                    start_beat=float(element.offset),
                    duration_beats=float(element.quarterLength),
                )
                if pitch.midi >= 60:
                    right_notes.append(note)
                else:
                    left_notes.append(note)

    right_notes.sort(key=lambda n: (n.start_beat, n.pitch))
    left_notes.sort(key=lambda n: (n.start_beat, n.pitch))

    tracks = []
    if right_notes:
        tracks.append(Track(hand="right", notes=right_notes))
    if left_notes:
        tracks.append(Track(hand="left", notes=left_notes))
    return tracks
