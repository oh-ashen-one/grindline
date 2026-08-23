#!/usr/bin/env bash
# cook_forever.sh — fully autonomous GRINDLINE loop.
# Relaunches cook.sh sessions until COMPLETE. Run under caffeinate in tmux.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG="$REPO_ROOT/cook.log"
COMPLETE_MARKER="<promise>COMPLETE</promise>"
MAX_SESSIONS="${MAX_SESSIONS:-60}"
COOLDOWN="${COOLDOWN:-20}"

cd "$REPO_ROOT"
for i in $(seq 1 "$MAX_SESSIONS"); do
  echo "" | tee -a "$LOG"
  echo "=== cook_forever: session $i start $(date '+%F %T') ===" | tee -a "$LOG"
  bash "$REPO_ROOT/reference/ox/cook.sh" >>"$LOG" 2>&1
  RC=$?
  echo "=== cook_forever: session $i ended rc=$RC $(date '+%F %T') ===" | tee -a "$LOG"
  if tail -100 "$LOG" | grep -q "$COMPLETE_MARKER"; then
    echo "=== COMPLETE DETECTED — stopping ($(date '+%F %T')) ===" | tee -a "$LOG"
    exit 0
  fi
  if [[ $RC -eq 42 ]]; then
    echo "=== exit 42 (all stories passed) but no COMPLETE marker — stopping for inspection ===" | tee -a "$LOG"
    exit 42
  fi
  sleep "$COOLDOWN"
done
echo "=== MAX_SESSIONS reached without COMPLETE ===" | tee -a "$LOG"
exit 1
