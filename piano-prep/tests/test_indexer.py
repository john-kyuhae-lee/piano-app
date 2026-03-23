"""Tests for corpus indexer."""

import sqlite3

from piano_prep.indexer import create_db, search_songs


def test_create_db(tmp_path):
    db_path = tmp_path / "test.db"
    conn = create_db(db_path)
    assert db_path.exists()
    # Check tables exist
    tables = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table'"
    ).fetchall()
    table_names = [t[0] for t in tables]
    assert "songs" in table_names
    assert "songs_fts" in table_names
    assert "song_neighbors" in table_names
    conn.close()


def test_search_empty_db(tmp_path):
    db_path = tmp_path / "test.db"
    create_db(db_path).close()
    results = search_songs(db_path, "bach")
    assert results == []


def test_search_with_data(tmp_path):
    db_path = tmp_path / "test.db"
    conn = create_db(db_path)
    conn.execute("""
        INSERT INTO songs (id, file_path, file_hash, title, composer, difficulty)
        VALUES ('test1', '/test.mxl', 'hash1', 'Test Song', 'Bach', 5.0)
    """)
    conn.commit()
    conn.close()

    results = search_songs(db_path, "Bach")
    assert len(results) == 1
    assert results[0]["title"] == "Test Song"


def test_search_empty_query_returns_all(tmp_path):
    db_path = tmp_path / "test.db"
    conn = create_db(db_path)
    for i in range(5):
        conn.execute(
            "INSERT INTO songs (id, file_path, file_hash, title, composer, difficulty) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            (f"id{i}", f"/test{i}.mxl", f"hash{i}", f"Song {i}", "Test", 3.0),
        )
    conn.commit()
    conn.close()

    results = search_songs(db_path, "", limit=10)
    assert len(results) == 5
