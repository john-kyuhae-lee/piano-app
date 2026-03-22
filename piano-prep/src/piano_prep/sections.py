"""Detect phrase/section boundaries for practice chunking."""

from __future__ import annotations

from .models import Note, Section, Track


def detect_sections(tracks: list[Track], time_sig: tuple[int, int]) -> list[Section]:
    """Detect section boundaries from note data.

    Strategy:
    1. Look for rests > 1 beat in the melody (right hand or first track)
    2. Fall back to grouping by N bars (default 4)
    """
    if not tracks:
        return []

    # Use the first track (usually right hand / melody)
    melody = tracks[0]
    beats_per_bar = time_sig[0] * (4.0 / time_sig[1])

    # Find the total song length in beats
    all_notes = [n for t in tracks for n in t.notes]
    if not all_notes:
        return []
    total_beats = max(n.start_beat + n.duration_beats for n in all_notes)

    # Try rest-based detection first
    sections = _detect_by_rests(melody.notes, total_beats, beats_per_bar)

    if len(sections) < 2:
        # Fall back to fixed-bar grouping
        sections = _detect_by_bars(total_beats, beats_per_bar, bars_per_section=4)

    # Label sections
    labels = _generate_labels(len(sections))
    for i, section in enumerate(sections):
        section.label = labels[i]

    return sections


def _detect_by_rests(
    notes: list[Note], total_beats: float, beats_per_bar: float
) -> list[Section]:
    """Find section boundaries at rests longer than 1 beat."""
    if not notes:
        return []

    sorted_notes = sorted(notes, key=lambda n: n.start_beat)
    boundaries: list[float] = [0.0]

    for i in range(len(sorted_notes) - 1):
        current_end = sorted_notes[i].start_beat + sorted_notes[i].duration_beats
        next_start = sorted_notes[i + 1].start_beat
        gap = next_start - current_end

        if gap >= 1.0:
            # Snap to nearest bar line
            bar_beat = round(next_start / beats_per_bar) * beats_per_bar
            if bar_beat > boundaries[-1]:
                boundaries.append(bar_beat)

    boundaries.append(total_beats)

    # Build sections from boundaries
    sections: list[Section] = []
    for i in range(len(boundaries) - 1):
        if boundaries[i + 1] > boundaries[i]:
            sections.append(Section(
                start_beat=boundaries[i],
                end_beat=boundaries[i + 1],
                label="",
            ))

    return sections


def _detect_by_bars(
    total_beats: float, beats_per_bar: float, bars_per_section: int
) -> list[Section]:
    """Group beats into fixed-size sections (default 4 bars each)."""
    beats_per_section = beats_per_bar * bars_per_section
    sections: list[Section] = []
    beat = 0.0

    while beat < total_beats:
        end = min(beat + beats_per_section, total_beats)
        sections.append(Section(start_beat=beat, end_beat=end, label=""))
        beat = end

    return sections


def _generate_labels(count: int) -> list[str]:
    """Generate section labels: A, B, C, ... A', B', ..."""
    if count <= 26:
        return [chr(65 + i) for i in range(count)]

    labels: list[str] = []
    for i in range(count):
        base = chr(65 + (i % 26))
        prime = "'" * (i // 26)
        labels.append(base + prime)
    return labels
