"""Serialize Song to game-ready JSON."""

from __future__ import annotations

import json
from pathlib import Path

from .models import Song


def write_song_json(song: Song, output_path: Path) -> None:
    """Write a Song to a JSON file in the game format."""
    output_path.parent.mkdir(parents=True, exist_ok=True)

    data = {
        "meta": {
            "title": song.meta.title,
            "composer": song.meta.composer,
            "difficulty": song.meta.difficulty,
            "tempo_bpm": song.meta.tempo_bpm,
            "time_signature": list(song.meta.time_signature),
            "duration_seconds": song.meta.duration_seconds,
            "key": song.meta.key,
        },
        "sections": [
            {
                "start_beat": s.start_beat,
                "end_beat": s.end_beat,
                "label": s.label,
            }
            for s in song.sections
        ],
        "tracks": [
            {
                "hand": t.hand,
                "notes": [
                    {
                        "pitch": n.pitch,
                        "start_beat": n.start_beat,
                        "duration_beats": n.duration_beats,
                        "finger": n.finger,
                    }
                    for n in t.notes
                ],
            }
            for t in song.tracks
        ],
    }

    with open(output_path, "w") as f:
        json.dump(data, f, indent=2)
