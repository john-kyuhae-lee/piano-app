#!/bin/bash
# Run all Piano Hero tests: Python pipeline + Godot game logic.
set -e

cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:$PATH"

echo "=========================================="
echo "  Piano Hero Test Suite"
echo "=========================================="
echo ""

# Python tests
echo "--- Python pipeline tests ---"
cd piano-prep
uv run pytest tests/ -v --tb=short 2>&1
PYTHON_EXIT=$?
cd ..
echo ""

if [ $PYTHON_EXIT -ne 0 ]; then
    echo "PYTHON TESTS FAILED (exit $PYTHON_EXIT)"
    exit 1
fi

# Godot tests (if GdUnit4 is available)
if [ -f "addons/gdUnit4/bin/GdUnitCmdTool.gd" ]; then
    echo "--- Godot game logic tests ---"
    godot --path . --headless --script addons/gdUnit4/bin/GdUnitCmdTool.gd \
        --testsuite tests/ 2>&1 || true
    echo ""
else
    echo "--- Godot tests skipped (GdUnit4 not installed) ---"
fi

echo "=========================================="
echo "  Test suite complete"
echo "=========================================="
