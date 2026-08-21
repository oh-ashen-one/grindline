#!/bin/bash
# Boot gate: main scene runs N frames headless without error output.
set -uo pipefail
source "$(dirname "$0")/env.sh"
FRAMES=${1:-30}
cd "$GAME_ROOT/game"
OUT=$("$GODOT" --headless --path . --quit-after "$FRAMES" 2>&1)
CODE=$?
echo "$OUT" | grep -qE "SCRIPT ERROR|ERROR:" && { echo "$OUT" | head -20; exit 1; }
exit $CODE
