#!/usr/bin/env bash
# cook.sh — launch/resume the GRINDLINE autonomous build loop.
# Each invocation is one ox-alpha working session; relaunch until COMPLETE.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GOAL="$REPO_ROOT/GOAL.md"

cd "$REPO_ROOT"
echo "=== cook: launching opencode session ($(date '+%F %T')) ==="
opencode run -m opencode/x-preview-f-free "$(cat "$GOAL")

Continue the GRINDLINE build. Start by reading OX-ALPHA.md, HANDOFF.md (if
present), scripts/ralph/prd.json (if present), then git log --oneline -15.
Pick up exactly where the last session left off."
