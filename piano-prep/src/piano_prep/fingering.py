"""Compute fingering using pianoplayer. Non-fatal on failure."""

from __future__ import annotations

from pathlib import Path

from .models import Track


def annotate_fingering(path: Path, tracks: list[Track]) -> None:
    """Try to compute fingering with pianoplayer. Modifies tracks in place.

    On failure, tracks are left unchanged (finger=None on all notes).
    pianoplayer is optional — if not installed, this is a no-op.
    """
    try:
        import pianoplayer.hand  # type: ignore[import-untyped]  # noqa: F401
    except ImportError:
        return

    for track in tracks:
        hand_side = "right" if track.hand == "right" else "left"
        try:
            _annotate_track(path, track, hand_side)
        except Exception:
            # pianoplayer crashes on malformed scores — non-fatal
            pass


def _annotate_track(path: Path, track: Track, hand_side: str) -> None:
    """Run pianoplayer on a single track and update finger numbers."""
    from pianoplayer.hand import Hand  # type: ignore[import-untyped]

    hand = Hand(hand_side, str(path))
    hand.noteseq  # noqa: B018  # triggers parsing
    hand.generate()

    # Map pianoplayer's finger annotations back to our notes
    if hasattr(hand, "noteseq") and hand.noteseq:
        finger_map: dict[tuple[int, float], int] = {}
        for pn in hand.noteseq:
            if hasattr(pn, "fingering") and pn.fingering:
                pitch = pn.pitch.midi if hasattr(pn.pitch, "midi") else pn.pitch
                offset = float(pn.offset) if hasattr(pn, "offset") else 0.0
                finger_map[(pitch, round(offset, 3))] = pn.fingering

        for note in track.notes:
            key = (note.pitch, round(note.start_beat, 3))
            if key in finger_map:
                note.finger = finger_map[key]
