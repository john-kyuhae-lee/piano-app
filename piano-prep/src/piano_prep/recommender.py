"""Content-based song recommendation engine.

Computes similarity between songs based on difficulty, key, tempo, composer,
and note density. Precomputes top-20 neighbors for each song and stores
them in the song_neighbors table.
"""

from __future__ import annotations

import math
import sqlite3
from pathlib import Path

from rich.console import Console
from rich.progress import Progress

console = Console()

# Circle of fifths distance for key similarity
KEY_FIFTHS = {
    "C major": 0, "G major": 1, "D major": 2, "A major": 3,
    "E major": 4, "B major": 5, "F# major": 6, "Gb major": 6,
    "Db major": -5, "Ab major": -4, "Eb major": -3, "Bb major": -2,
    "F major": -1,
    "A minor": 0, "E minor": 1, "B minor": 2, "F# minor": 3,
    "C# minor": 4, "G# minor": 5, "D# minor": 6, "Eb minor": 6,
    "Bb minor": -5, "F minor": -4, "C minor": -3, "G minor": -2,
    "D minor": -1,
}

# Weights for each feature in the similarity computation
WEIGHTS = {
    "difficulty": 3.0,
    "tempo": 2.0,
    "key": 1.5,
    "density": 1.5,
    "composer": 2.0,
}


def compute_neighbors(db_path: Path, top_k: int = 20) -> int:
    """Precompute top-K similar songs for every song in the database.

    Returns number of neighbor pairs computed.
    """
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row

    songs = conn.execute("""
        SELECT id, title, composer, key_sig, tempo_bpm, difficulty, density
        FROM songs
    """).fetchall()

    if len(songs) < 2:
        conn.close()
        return 0

    # Build feature vectors
    features: dict[str, dict[str, float]] = {}
    composers: dict[str, str] = {}
    for s in songs:
        sid = s["id"]
        composers[sid] = s["composer"] or "Unknown"
        features[sid] = {
            "difficulty": float(s["difficulty"] or 5.0),
            "tempo": float(s["tempo_bpm"] or 120) / 200.0,  # Normalize to ~0-1
            "key": float(KEY_FIFTHS.get(s["key_sig"] or "C major", 0)) / 6.0,  # Normalize
            "density": float(s["density"] or 0.0) / 5.0,  # Normalize
        }

    # Clear existing neighbors
    conn.execute("DELETE FROM song_neighbors")

    # Compute pairwise distances and keep top-K
    total_pairs = 0
    song_ids = list(features.keys())

    with Progress(console=console) as progress:
        task = progress.add_task("Computing recommendations...", total=len(song_ids))

        for i, sid in enumerate(song_ids):
            progress.advance(task)
            distances: list[tuple[str, float]] = []

            for j, other_id in enumerate(song_ids):
                if i == j:
                    continue

                dist = _compute_distance(
                    features[sid], features[other_id],
                    composers[sid], composers[other_id],
                )
                distances.append((other_id, dist))

            # Sort by distance and keep top-K
            distances.sort(key=lambda x: x[1])
            top_neighbors = distances[:top_k]

            for neighbor_id, dist in top_neighbors:
                conn.execute(
                    "INSERT INTO song_neighbors (song_id, neighbor_id, distance) VALUES (?, ?, ?)",
                    (sid, neighbor_id, round(dist, 4)),
                )
                total_pairs += 1

    conn.commit()
    conn.close()
    return total_pairs


def get_recommendations(db_path: Path, song_id: str, limit: int = 10) -> list[dict]:
    """Get recommended songs similar to the given song."""
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row

    rows = conn.execute("""
        SELECT s.*, sn.distance
        FROM song_neighbors sn
        JOIN songs s ON s.id = sn.neighbor_id
        WHERE sn.song_id = ?
        ORDER BY sn.distance
        LIMIT ?
    """, (song_id, limit)).fetchall()

    results = [dict(row) for row in rows]
    conn.close()
    return results


def _compute_distance(
    feat_a: dict[str, float],
    feat_b: dict[str, float],
    composer_a: str,
    composer_b: str,
) -> float:
    """Compute weighted Euclidean distance between two songs."""
    dist_sq = 0.0

    for key in ("difficulty", "tempo", "key", "density"):
        diff = feat_a[key] - feat_b[key]
        dist_sq += WEIGHTS[key] * diff * diff

    # Composer bonus: same composer = closer
    if composer_a != composer_b:
        dist_sq += WEIGHTS["composer"] * 0.5 * 0.5  # 0.5 penalty for different composer

    return math.sqrt(dist_sq)
