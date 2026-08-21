#!/bin/bash
# Parse gate: every .gd in game/ (minus addons/, sim/tests fixtures are INCLUDED)
# must pass --check-only. Godot exits 0 even on parse errors — judge by text.
set -uo pipefail
source "$(dirname "$0")/env.sh"
cd "$GAME_ROOT/game"
FAIL=0
while IFS= read -r -d '' f; do
  OUT=$("$GODOT" --headless --check-only --path . --script "res://${f#./}" 2>&1)
  if echo "$OUT" | grep -qE "SCRIPT ERROR|Parse Error|Failed to load script"; then
    echo "PARSE FAIL: $f"
    echo "$OUT" | grep -iE "error|line" | head -10
    FAIL=1
  fi
done < <(find . -name '*.gd' -not -path './addons/*' -not -path './.godot/*' -print0 2>/dev/null)
exit $FAIL
