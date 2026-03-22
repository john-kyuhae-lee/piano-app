#!/bin/bash
# Launch Piano Hero, screenshot the game window, then kill it.
# Usage: ./scripts/tools/screenshot.sh [output_path]
# Default output: /tmp/piano-hero-screenshot.png

OUTPUT="${1:-/tmp/piano-hero-screenshot.png}"
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

cd "$PROJECT_DIR" || exit 1

# Launch Godot (not editor mode — just run the game)
godot --path . -- &>/dev/null &
GODOT_PID=$!

sleep 2

# Find the Piano Hero game window (largest one if multiple)
ADDR=$(hyprctl clients -j | jq -r '
  [.[] | select(.class == "Piano Hero")] |
  sort_by(.size[0] * .size[1]) | last | .address
')

if [ -n "$ADDR" ] && [ "$ADDR" != "null" ]; then
    hyprctl dispatch focuswindow "address:$ADDR" &>/dev/null
    sleep 0.3
    GEOM=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
    grim -g "$GEOM" "$OUTPUT"
    echo "$OUTPUT"
else
    echo "ERROR: Could not find Piano Hero window" >&2
    grim "$OUTPUT"
    echo "$OUTPUT (full screen fallback)"
fi

kill $GODOT_PID &>/dev/null
wait $GODOT_PID &>/dev/null 2>&1
