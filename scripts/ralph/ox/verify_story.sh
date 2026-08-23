#!/usr/bin/env bash
# verify_story.sh US-xxx — run one story's mechanical verify from prd.json.
# Full output lands in LAST_VERIFY.txt (the forensic record the loop reads).
# Exit code mirrors the verify itself. Run from the project root.
set -uo pipefail

STORY="${1:?usage: verify_story.sh <US-id>}"
PRD="${PRD_FILE:-scripts/ralph/prd.json}"
OUT="${LAST_VERIFY:-LAST_VERIFY.txt}"

CMD=$(jq -r --arg id "$STORY" '.userStories[] | select(.id==$id) | .verify // empty' "$PRD")
[[ -z "$CMD" ]] && { echo "verify_story: no story '$STORY' or no verify command in $PRD"; exit 2; }

echo "[ox-alpha verify] $STORY :: $CMD" | tee "$OUT"
bash -c "$CMD" >>"$OUT" 2>&1
RC=$?
if [[ $RC -eq 0 ]]; then
  echo "VERIFY PASS ($STORY)" | tee -a "$OUT"
else
  echo "VERIFY FAIL ($STORY) exit=$RC — see $OUT" | tee -a "$OUT"
fi
exit $RC
