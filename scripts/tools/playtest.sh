#!/bin/bash
# Launch Piano Hero with telemetry + capture, play Twinkle Twinkle via ydotool,
# then output results.
#
# Usage: ./scripts/tools/playtest.sh [--keys-only "z z b b ..."]
#
# Keyboard mapping (matches MidiManager):
#   Z=C4(60)  X=D4(62)  C=E4(64)  V=F4(65)  B=G4(67)  N=A4(69)  M=B4(71)
#
# Outputs:
#   - Telemetry JSONL at user://debug_telemetry.jsonl
#   - Screenshots at user://captures/
#   - Summary printed to stdout
#   - Exit code 0 = song completed, 1 = something went wrong

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT_USER_DIR="$HOME/.local/share/godot/app_userdata/Piano Hero"
TELEMETRY_FILE="$GODOT_USER_DIR/debug_telemetry.jsonl"
CAPTURE_DIR="$GODOT_USER_DIR/captures"

# Twinkle Twinkle Little Star — right hand, full song
# First key starts the game (READY → PLAYING), does NOT clear a note.
# Then: C C G G A A G(hold) F F E E D D C(hold)
TWINKLE_KEYS="z z z b b n n b v v c c x x z"

# Allow custom key sequence
KEYS="${1:-$TWINKLE_KEYS}"

# Key name to ydotool keycode mapping
declare -A KEYCODES=(
    [z]=44 [x]=45 [c]=46 [v]=47 [b]=48 [n]=49 [m]=50
    [s]=31 [d]=32 [g]=34 [h]=35 [j]=36 [l]=38
    [comma]=51 [period]=52 [slash]=53 [semicolon]=39
)

# Clean previous results
rm -f "$TELEMETRY_FILE"
rm -rf "$CAPTURE_DIR"
mkdir -p "$CAPTURE_DIR"

# Launch game with debug flags
cd "$PROJECT_DIR"
godot --path . -- --telemetry --capture &>/dev/null &
GODOT_PID=$!

cleanup() {
    kill "$GODOT_PID" &>/dev/null || true
    wait "$GODOT_PID" &>/dev/null 2>&1 || true
}
trap cleanup EXIT

# Wait for game window
sleep 2

# Focus the Piano Hero window
focus_game() {
    local addr
    addr=$(hyprctl clients -j | jq -r '
        [.[] | select(.class == "Piano Hero")] |
        sort_by(.size[0] * .size[1]) | last | .address
    ')
    if [ -n "$addr" ] && [ "$addr" != "null" ]; then
        hyprctl dispatch focuswindow "address:$addr" &>/dev/null
        sleep 0.2
        return 0
    fi
    return 1
}

focus_game || { echo "ERROR: Could not find Piano Hero window"; exit 1; }

# Play the sequence
# First keypress transitions READY → PLAYING (1.5s lead-in before first note).
# At 100 BPM, each beat = 0.6s. Wait for note to reach hit line before pressing.
echo "Playing keys: $KEYS"
FIRST=true
for key in $KEYS; do
    code="${KEYCODES[$key]:-}"
    if [ -z "$code" ]; then
        echo "WARNING: Unknown key '$key', skipping"
        continue
    fi
    focus_game || true
    ydotool key "${code}:1" "${code}:0"

    if [ "$FIRST" = true ]; then
        # First key starts the game. Wait for lead-in (1.5s) + first note travel.
        FIRST=false
        sleep 2.0
    else
        # Wait for next note to reach hit line.
        # At 100 BPM, quarter=0.6s, half=1.2s. Use 1.3s to handle half notes.
        sleep 1.3
    fi
done

# Wait for song to finish processing
sleep 1

# Output results
echo ""
echo "=== TELEMETRY ==="
if [ -f "$TELEMETRY_FILE" ]; then
    echo "File: $TELEMETRY_FILE"

    # Show summary line if present
    local_summary=$(grep '"song_completed"' "$TELEMETRY_FILE" 2>/dev/null || true)
    if [ -n "$local_summary" ]; then
        echo "RESULT: Song completed!"
        echo "$local_summary" | jq .
        EXIT_CODE=0
    else
        echo "RESULT: Song NOT completed"
        # Show last few events
        tail -5 "$TELEMETRY_FILE" | jq .
        EXIT_CODE=1
    fi

    echo ""
    echo "Event counts:"
    jq -r '.event' "$TELEMETRY_FILE" | sort | uniq -c | sort -rn
else
    echo "ERROR: No telemetry file found"
    EXIT_CODE=1
fi

echo ""
echo "=== CAPTURES ==="
if [ -d "$CAPTURE_DIR" ]; then
    ls -la "$CAPTURE_DIR"/*.png 2>/dev/null || echo "No screenshots captured"
else
    echo "No capture directory"
fi

exit "${EXIT_CODE:-1}"
