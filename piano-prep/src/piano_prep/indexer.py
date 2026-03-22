"""Build and manage the SQLite song index for search."""

from __future__ import annotations

import gc
import hashlib
import sqlite3
from pathlib import Path

import music21
from rich.console import Console
from rich.progress import Progress

from .metadata import _build_metadata, _compute_difficulty
from .models import SongMeta, Track
from .parser import parse_musicxml

console = Console()

SCHEMA = """
CREATE TABLE IF NOT EXISTS songs (
    id TEXT PRIMARY KEY,
    file_path TEXT NOT NULL,
    file_hash TEXT NOT NULL,
    title TEXT NOT NULL,
    composer TEXT NOT NULL DEFAULT 'Unknown',
    key_sig TEXT,
    tempo_bpm INTEGER DEFAULT 120,
    time_sig_num INTEGER DEFAULT 4,
    time_sig_den INTEGER DEFAULT 4,
    difficulty REAL DEFAULT 5.0,
    duration_seconds REAL DEFAULT 0.0,
    note_count INTEGER DEFAULT 0,
    hand_count INTEGER DEFAULT 1,
    pitch_min INTEGER,
    pitch_max INTEGER,
    density REAL DEFAULT 0.0,
    prepared INTEGER DEFAULT 0
);

CREATE VIRTUAL TABLE IF NOT EXISTS songs_fts USING fts5(
    title, composer, content=songs, content_rowid=rowid,
    tokenize='porter'
);

CREATE TRIGGER IF NOT EXISTS songs_ai AFTER INSERT ON songs BEGIN
    INSERT INTO songs_fts(rowid, title, composer)
    VALUES (new.rowid, new.title, new.composer);
END;

CREATE TRIGGER IF NOT EXISTS songs_ad AFTER DELETE ON songs BEGIN
    INSERT INTO songs_fts(songs_fts, rowid, title, composer)
    VALUES ('delete', old.rowid, old.title, old.composer);
END;

CREATE TRIGGER IF NOT EXISTS songs_au AFTER UPDATE ON songs BEGIN
    INSERT INTO songs_fts(songs_fts, rowid, title, composer)
    VALUES ('delete', old.rowid, old.title, old.composer);
    INSERT INTO songs_fts(rowid, title, composer)
    VALUES (new.rowid, new.title, new.composer);
END;

CREATE TABLE IF NOT EXISTS song_neighbors (
    song_id TEXT NOT NULL,
    neighbor_id TEXT NOT NULL,
    distance REAL NOT NULL,
    PRIMARY KEY (song_id, neighbor_id)
);
"""


def create_db(db_path: Path) -> sqlite3.Connection:
    """Create the database and schema."""
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    conn.execute("PRAGMA journal_mode=WAL")
    conn.executescript(SCHEMA)
    conn.commit()
    return conn


def index_corpus_dir(corpus_dir: Path, db_path: Path) -> dict[str, int]:
    """Index all .mxl/.xml files in a directory into the SQLite database.

    Returns stats dict with counts of processed, skipped, failed files.
    """
    conn = create_db(db_path)
    files = list(corpus_dir.rglob("*.mxl")) + list(corpus_dir.rglob("*.xml"))
    files = [f for f in files if f.stat().st_size < 50 * 1024 * 1024]

    # Get existing hashes for incremental indexing
    existing = {}
    for row in conn.execute("SELECT file_path, file_hash FROM songs"):
        existing[row[0]] = row[1]

    stats = {"processed": 0, "skipped": 0, "failed": 0}

    with Progress(console=console) as progress:
        task = progress.add_task("Indexing corpus...", total=len(files))

        for file_path in files:
            progress.advance(task)
            rel_path = str(file_path)
            file_hash = hashlib.sha256(file_path.read_bytes()).hexdigest()[:16]

            # Skip unchanged files
            if rel_path in existing and existing[rel_path] == file_hash:
                stats["skipped"] += 1
                continue

            try:
                _index_single_file(conn, file_path, rel_path, file_hash)
                stats["processed"] += 1
            except Exception as e:
                stats["failed"] += 1
                if stats["failed"] <= 5:
                    console.print(f"  [dim]Failed: {file_path.name}: {e}[/dim]")

    conn.commit()
    conn.close()
    return stats


def index_music21_corpus(db_path: Path, limit: int = 0) -> dict[str, int]:
    """Index pieces from music21's built-in corpus (for bootstrapping).

    Filters for piano-appropriate pieces.
    """
    conn = create_db(db_path)
    paths = music21.corpus.getComposer("bach") + \
            music21.corpus.getComposer("mozart") + \
            music21.corpus.getComposer("beethoven") + \
            music21.corpus.getComposer("chopin") + \
            music21.corpus.getComposer("haydn") + \
            music21.corpus.getComposer("schubert") + \
            music21.corpus.getComposer("schumann")

    if limit > 0:
        paths = paths[:limit]

    stats = {"processed": 0, "skipped": 0, "failed": 0}

    with Progress(console=console) as progress:
        task = progress.add_task("Indexing music21 corpus...", total=len(paths))

        for corpus_path in paths:
            progress.advance(task)
            try:
                path = Path(str(corpus_path))
                file_hash = hashlib.sha256(str(corpus_path).encode()).hexdigest()[:16]
                rel_path = str(corpus_path)

                # Check if already indexed
                row = conn.execute(
                    "SELECT file_hash FROM songs WHERE file_path = ?", (rel_path,)
                ).fetchone()
                if row and row[0] == file_hash:
                    stats["skipped"] += 1
                    continue

                _index_single_file(conn, path, rel_path, file_hash, use_corpus=True)
                stats["processed"] += 1
            except Exception as e:
                stats["failed"] += 1
                if stats["failed"] <= 5:
                    console.print(f"  [dim]Failed: {corpus_path}: {e}[/dim]")

    conn.commit()
    conn.close()
    return stats


def search_songs(db_path: Path, query: str, limit: int = 20) -> list[dict]:
    """Search the song index using FTS5."""
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row

    if query.strip():
        # FTS5 search
        rows = conn.execute("""
            SELECT s.* FROM songs s
            JOIN songs_fts fts ON s.rowid = fts.rowid
            WHERE songs_fts MATCH ?
            ORDER BY rank
            LIMIT ?
        """, (query, limit)).fetchall()
    else:
        # No query — return recent/popular
        rows = conn.execute("""
            SELECT * FROM songs
            ORDER BY title
            LIMIT ?
        """, (limit,)).fetchall()

    results = [dict(row) for row in rows]
    conn.close()
    return results


def _index_single_file(
    conn: sqlite3.Connection,
    file_path: Path,
    rel_path: str,
    file_hash: str,
    use_corpus: bool = False,
) -> None:
    """Index a single MusicXML file into the database."""
    if use_corpus:
        score = music21.corpus.parse(str(file_path), forceSource=True)
    else:
        score = music21.converter.parse(str(file_path), forceSource=True)

    try:
        tracks = _extract_tracks_fast(score)
        if not tracks:
            return

        all_notes = [n for t in tracks for n in t]
        if not all_notes:
            return

        # Metadata
        title = file_path.stem
        composer = "Unknown"
        if score.metadata:
            if score.metadata.title:
                title = str(score.metadata.title).strip()
            for attr in ("composer", "creator"):
                val = getattr(score.metadata, attr, None)
                if val:
                    composer = str(val).strip()
                    break

        key_sig = "Unknown"
        try:
            k = score.analyze("key")
            if k:
                key_sig = str(k)
        except Exception:
            pass

        tempo_bpm = 120
        for mm in score.flatten().getElementsByClass(music21.tempo.MetronomeMark):
            if mm.number is not None:
                tempo_bpm = int(mm.number)
                break

        ts_num, ts_den = 4, 4
        for ts in score.flatten().getElementsByClass(music21.meter.TimeSignature):
            ts_num, ts_den = ts.numerator, ts.denominator
            break

        duration_seconds = float(score.duration.quarterLength) * (60.0 / tempo_bpm)

        pitches = [n[0] for n in all_notes]
        pitch_min = min(pitches)
        pitch_max = max(pitches)
        note_count = len(all_notes)
        hand_count = len(tracks)
        density = note_count / max(duration_seconds, 1.0)
        difficulty = _compute_difficulty_fast(
            all_notes, tempo_bpm, duration_seconds, hand_count
        )

        song_id = file_hash

        conn.execute("""
            INSERT OR REPLACE INTO songs
            (id, file_path, file_hash, title, composer, key_sig, tempo_bpm,
             time_sig_num, time_sig_den, difficulty, duration_seconds,
             note_count, hand_count, pitch_min, pitch_max, density, prepared)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
        """, (song_id, rel_path, file_hash, title, composer, key_sig, tempo_bpm,
              ts_num, ts_den, round(difficulty, 1), round(duration_seconds, 1),
              note_count, hand_count, pitch_min, pitch_max, round(density, 2)))

    finally:
        del score
        gc.collect()


def _extract_tracks_fast(score: music21.stream.Score) -> list[list[tuple]]:
    """Fast note extraction — returns list of tracks, each a list of (pitch, beat, dur) tuples."""
    parts = list(score.parts)
    if not parts:
        return []

    tracks = []
    for part in parts[:2]:  # Max 2 tracks (right + left)
        notes = []
        for element in part.flatten().notesAndRests:
            if isinstance(element, music21.note.Note):
                notes.append((element.pitch.midi, float(element.offset), float(element.quarterLength)))
            elif isinstance(element, music21.chord.Chord):
                for pitch in element.pitches:
                    notes.append((pitch.midi, float(element.offset), float(element.quarterLength)))
        if notes:
            tracks.append(notes)

    return tracks


def _compute_difficulty_fast(
    notes: list[tuple], tempo_bpm: int, duration_seconds: float, hand_count: int
) -> float:
    """Compute difficulty from raw note tuples."""
    if not notes:
        return 1.0

    density = len(notes) / max(duration_seconds, 1.0)
    density_score = min(density / 5.0, 1.0)

    pitches = [n[0] for n in notes]
    ambitus = max(pitches) - min(pitches)
    ambitus_score = min(ambitus / 48.0, 1.0)

    durations = set(round(n[2], 3) for n in notes)
    rhythm_score = min(len(durations) / 6.0, 1.0)

    tempo_score = min(tempo_bpm / 160.0, 1.0)
    hand_score = 0.5 if hand_count >= 2 else 0.0

    difficulty = (
        density_score * 3.0
        + ambitus_score * 1.5
        + rhythm_score * 1.5
        + tempo_score * 2.0
        + hand_score * 2.0
    ) / 10.0 * 9.0 + 1.0

    return min(max(difficulty, 1.0), 10.0)
