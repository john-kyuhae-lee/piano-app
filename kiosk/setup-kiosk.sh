#!/bin/bash
# Set up Piano Hero kiosk mode on Omarchy/Hyprland.
# Run once after initial setup.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Setting up Piano Hero kiosk..."

# Make launcher executable
chmod +x "$SCRIPT_DIR/piano-hero.sh"

# Add to Hyprland autostart
AUTOSTART="$HOME/.config/hypr/autostart.conf"
if ! grep -q "piano-hero" "$AUTOSTART" 2>/dev/null; then
    echo "" >> "$AUTOSTART"
    echo "# Piano Hero kiosk — auto-launch on login" >> "$AUTOSTART"
    echo "exec-once = $SCRIPT_DIR/piano-hero.sh" >> "$AUTOSTART"
    echo "Added Piano Hero to Hyprland autostart"
else
    echo "Already in Hyprland autostart"
fi

# Add admin mode keybinding (Ctrl+Shift+A → open terminal)
BINDINGS="$HOME/.config/hypr/bindings.conf"
if ! grep -q "Admin mode" "$BINDINGS" 2>/dev/null; then
    echo "" >> "$BINDINGS"
    echo "# Admin mode — exit kiosk to terminal" >> "$BINDINGS"
    echo 'bindd = CTRL SHIFT, A, Admin mode, exec, xdg-terminal-exec' >> "$BINDINGS"
    echo "Added Ctrl+Shift+A admin keybinding"
else
    echo "Admin keybinding already configured"
fi

# Install systemd user service for crash recovery
mkdir -p "$HOME/.config/systemd/user"
cp "$SCRIPT_DIR/piano-hero.service" "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
echo "Systemd service installed (not enabled — use autostart instead)"

# Index the corpus if not already done
if [ ! -f "$PROJECT_DIR/corpus.db" ]; then
    echo "Building song index..."
    cd "$PROJECT_DIR/piano-prep"
    ~/.local/bin/uv run piano-prep index --use-builtin --db-path ../corpus.db
    ~/.local/bin/uv run piano-prep recommend --db-path ../corpus.db
    echo "Song index built"
else
    echo "Song index already exists"
fi

echo ""
echo "Kiosk setup complete!"
echo "  - Auto-launch: Hyprland exec-once"
echo "  - Admin mode: Ctrl+Shift+A opens terminal"
echo "  - Crash recovery: systemd service (enable with: systemctl --user enable piano-hero)"
echo "  - Restart: hyprctl dispatch exec '$SCRIPT_DIR/piano-hero.sh'"
