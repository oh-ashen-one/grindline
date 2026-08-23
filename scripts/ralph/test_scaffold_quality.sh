#!/bin/bash
# Scaffold smoke test: every future project starts hard-blocked and complete.
set -euo pipefail

REF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TMP_ROOT=$(mktemp -d)
PROJECT="$TMP_ROOT/game"
LOG="$TMP_ROOT/scaffold.log"
trap 'rm -rf "$TMP_ROOT"' EXIT

bash "$REF_DIR/scaffold_project.sh" "$PROJECT" "Quality Fixture" 3d > "$LOG" 2>&1

test -f "$PROJECT/.ralph-quality-required"
test "$(tr -d '\n' < "$PROJECT/scripts/ralph/PHASE")" = "1"
test -f "$PROJECT/quality/contract.json"
test -f "$PROJECT/quality/QUALITY-LEDGER.md"
test -f "$PROJECT/assets/asset-manifest.json"
test -x "$PROJECT/tests_staged/test_q07_critique_ship.sh"
grep -q 'NO PRIMITIVE PLACEHOLDERS' "$PROJECT/scripts/ralph/QWEN.md"

if grep -q 'No such file or directory' "$LOG"; then
  echo "test_scaffold_quality: scaffold emitted a shell/path error" >&2
  sed -n '1,120p' "$LOG" >&2
  exit 1
fi

if python3 "$PROJECT/scripts/ralph/quality/preflight_quality.py" \
  --root "$PROJECT" --max-errors 5 >/dev/null 2>&1; then
  echo "test_scaffold_quality: incomplete scaffold unexpectedly passed" >&2
  exit 1
fi

echo "test_scaffold_quality: OK"
