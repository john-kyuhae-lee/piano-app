"""CLI entry point for piano-prep."""

from __future__ import annotations

import hashlib
from pathlib import Path

import typer
from rich.console import Console

from .fingering import annotate_fingering
from .metadata import extract_metadata
from .models import Song
from .parser import parse_musicxml
from .sections import detect_sections
from .writer import write_song_json

app = typer.Typer(help="Piano Hero song preparation pipeline.")
console = Console()


@app.command()
def prepare(
    input_file: Path = typer.Argument(..., help="Path to .mxl or .xml MusicXML file"),
    output_dir: Path = typer.Option(
        Path("../songs"), help="Output directory for prepared JSON"
    ),
    skip_fingering: bool = typer.Option(False, help="Skip pianoplayer fingering"),
) -> None:
    """Prepare a MusicXML file for Piano Hero."""
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

    # Parse
    with console.status("Parsing MusicXML..."):
        tracks = parse_musicxml(input_file)

    if not tracks:
        console.print("[red]No notes found in file[/red]")
        raise typer.Exit(1)

    total_notes = sum(len(t.notes) for t in tracks)
    console.print(f"  Found {total_notes} notes in {len(tracks)} track(s)")

    # Metadata
    with console.status("Extracting metadata..."):
        meta = extract_metadata(input_file, tracks)

    console.print(f"  Title: {meta.title}")
    console.print(f"  Composer: {meta.composer}")
    console.print(f"  Key: {meta.key}, Tempo: {meta.tempo_bpm} BPM")
    console.print(f"  Difficulty: {meta.difficulty}/10")

    # Sections
    with console.status("Detecting sections..."):
        sections = detect_sections(tracks, meta.time_signature)

    console.print(f"  Sections: {len(sections)}")

    # Fingering
    if not skip_fingering:
        with console.status("Computing fingering..."):
            annotate_fingering(input_file, tracks)

        fingered = sum(1 for t in tracks for n in t.notes if n.finger is not None)
        console.print(f"  Fingered: {fingered}/{total_notes} notes")
    else:
        console.print("  Fingering: skipped")

    # Write
    song = Song(meta=meta, sections=sections, tracks=tracks)
    song_id = _compute_song_id(input_file)
    output_path = output_dir / f"{song_id}.json"

    write_song_json(song, output_path)
    console.print(f"[green]✓ Written:[/green] {output_path}")


def _compute_song_id(path: Path) -> str:
    """SHA256 hash of file content, first 12 hex chars."""
    h = hashlib.sha256(path.read_bytes()).hexdigest()
    return h[:12]


if __name__ == "__main__":
    app()
