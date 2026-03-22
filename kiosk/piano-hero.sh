#!/bin/bash
# Piano Hero kiosk launcher
# Starts the game in fullscreen. Restarts on crash.
# Used by Hyprland autostart and systemd service.

set -euo pipefail

PROJECT_DIR="${PIANO_HERO_DIR:-$HOME/piano-app}"
GODOT="${GODOT_BIN:-godot}"
LOG_DIR="$HOME/.local/share/piano-hero"
LOG_FILE="$LOG_DIR/kiosk.log"

mkdir -p "$LOG_DIR"

echo "$(date): Piano Hero kiosk starting" >> "$LOG_FILE"

# Ensure ydotoold is running for debug input
pidof ydotoold &>/dev/null || (ydotoold &disown)

# Start the game
exec "$GODOT" --path "$PROJECT_DIR" --fullscreen 2>> "$LOG_FILE"
