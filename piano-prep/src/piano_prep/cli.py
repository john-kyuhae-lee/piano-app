"""CLI entry point for piano-prep."""

from __future__ import annotations

import hashlib
from pathlib import Path

import typer
from rich.console import Console

from .fingering import annotate_fingering
from .indexer import index_corpus_dir, index_music21_corpus, search_songs
from .metadata import extract_metadata
from .models import Song
from .parser import parse_musicxml
from .sections import detect_sections
from .writer import write_song_json

app = typer.Typer(help="Piano Hero song preparation pipeline.")
console = Console()

DEFAULT_DB = Path("../corpus.db")


@app.command()
def prepare(
    input_file: Path = typer.Argument(..., help="Path to .mxl or .xml MusicXML file"),
    output_dir: Path = typer.Option(
        Path("../songs"), help="Output directory for prepared JSON"
    ),
    skip_fingering: bool = typer.Option(False, help="Skip pianoplayer fingering"),
) -> None:
    """Prepare a single MusicXML file for Piano Hero."""
    if not input_file.exists():
        console.print(f"[red]File not found: {input_file}[/red]")
        raise typer.Exit(1)

    ext = input_file.suffix.lower()
    if ext not in (".mxl", ".xml", ".musicxml"):
        console.print(f"[red]Unsupported format: {ext} (need .mxl or .xml)[/red]")
        raise typer.Exit(1)

    file_size = input_file.stat().st_size
    if file_size > 50 * 1024 * 1024:
        console.print(f"[red]File too large: {file_size / 1024 / 1024:.0f}MB (max 50MB)[/red]")
        raise typer.Exit(1)

    console.print(f"[bold]Preparing:[/bold] {input_file.name}")

    with console.status("Parsing MusicXML..."):
        tracks = parse_musicxml(input_file)

    if not tracks:
        console.print("[red]No notes found in file[/red]")
        raise typer.Exit(1)

    total_notes = sum(len(t.notes) for t in tracks)
    console.print(f"  Found {total_notes} notes in {len(tracks)} track(s)")

    with console.status("Extracting metadata..."):
        meta = extract_metadata(input_file, tracks)

    console.print(f"  Title: {meta.title}")
    console.print(f"  Composer: {meta.composer}")
    console.print(f"  Key: {meta.key}, Tempo: {meta.tempo_bpm} BPM")
    console.print(f"  Difficulty: {meta.difficulty}/10")

    with console.status("Detecting sections..."):
        sections = detect_sections(tracks, meta.time_signature)

    console.print(f"  Sections: {len(sections)}")

    if not skip_fingering:
        with console.status("Computing fingering..."):
            annotate_fingering(input_file, tracks)
        fingered = sum(1 for t in tracks for n in t.notes if n.finger is not None)
        console.print(f"  Fingered: {fingered}/{total_notes} notes")
    else:
        console.print("  Fingering: skipped")

    song = Song(meta=meta, sections=sections, tracks=tracks)
    song_id = _compute_song_id(input_file)
    output_path = output_dir / f"{song_id}.json"

    write_song_json(song, output_path)
    console.print(f"[green]✓ Written:[/green] {output_path}")


@app.command()
def index(
    corpus_dir: Path = typer.Argument(
        None, help="Directory of .mxl/.xml files to index"
    ),
    db_path: Path = typer.Option(DEFAULT_DB, help="SQLite database path"),
    use_builtin: bool = typer.Option(
        False, help="Index music21's built-in corpus instead of a directory"
    ),
    limit: int = typer.Option(0, help="Max files to index (0 = all)"),
) -> None:
    """Build the song search index from a corpus of MusicXML files."""
    if use_builtin:
        console.print("[bold]Indexing music21 built-in corpus...[/bold]")
        stats = index_music21_corpus(db_path, limit=limit)
    elif corpus_dir is not None:
        if not corpus_dir.exists():
            console.print(f"[red]Directory not found: {corpus_dir}[/red]")
            raise typer.Exit(1)
        console.print(f"[bold]Indexing:[/bold] {corpus_dir}")
        stats = index_corpus_dir(corpus_dir, db_path)
    else:
        console.print("[red]Provide a corpus directory or use --use-builtin[/red]")
        raise typer.Exit(1)

    console.print(f"[green]✓ Done:[/green] {stats['processed']} indexed, "
                  f"{stats['skipped']} skipped, {stats['failed']} failed")


@app.command()
def search(
    query: str = typer.Argument(..., help="Search query (title or composer)"),
    db_path: Path = typer.Option(DEFAULT_DB, help="SQLite database path"),
    limit: int = typer.Option(20, help="Max results"),
) -> None:
    """Search the song index."""
    if not db_path.exists():
        console.print(f"[red]Database not found: {db_path}[/red]")
        console.print("Run 'piano-prep index' first to build the index.")
        raise typer.Exit(1)

    results = search_songs(db_path, query, limit=limit)

    if not results:
        console.print(f"No results for '{query}'")
        return

    console.print(f"[bold]{len(results)} results for '{query}':[/bold]")
    for r in results:
        stars = "★" * max(1, min(5, int(r["difficulty"] / 2)))
        console.print(
            f"  {stars:5s}  {r['title'][:40]:40s}  {r['composer'][:20]:20s}  "
            f"{r['tempo_bpm']:3d}bpm  {r['duration_seconds']:.0f}s"
        )


@app.command("search-json")
def search_json(
    query: str = typer.Argument("", help="Search query (title or composer)"),
    db_path: Path = typer.Option(DEFAULT_DB, help="SQLite database path"),
    limit: int = typer.Option(20, help="Max results"),
) -> None:
    """Search the song index and output JSON (for Godot integration)."""
    import json as json_mod
    import warnings
    warnings.filterwarnings("ignore")

    if not db_path.exists():
        print("[]")
        raise typer.Exit(1)

    results = search_songs(db_path, query, limit=limit)
    print(json_mod.dumps(results))


def _compute_song_id(path: Path) -> str:
    """SHA256 hash of file content, first 12 hex chars."""
    h = hashlib.sha256(path.read_bytes()).hexdigest()
    return h[:12]


if __name__ == "__main__":
    app()
