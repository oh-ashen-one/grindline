#!/bin/bash
# US-101 — sim bridge transport mechanics on a bare world.
# Pixel-producing screenshots are gated to windowed runs from phase 2
# (look-lock); here we assert transport mechanics and honesty.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate
CMDS="$(mktemp -t grindline)"
cat > "$CMDS" <<'JSON'
{
  "seed": 1,
  "steps": [
    {"op": "noop"},
    {"op": "assert", "name": "phase_defaults_none", "state": "app.phase == 'none'"},
    {"op": "unknown_future_op"}
  ],
  "gate": true
}
JSON
run_sim "$CMDS"; RC=$?
[[ $RC -eq 0 || $RC -eq 1 ]] || die "bridge crashed (rc=$RC)"
grep -q "^SIM RESULT {" "$SIM_OUT" || die "no parseable SIM RESULT line"
python3 - "$SIM_OUT" <<'PYEOF' || exit 1
import json, sys
lines = [l for l in open(sys.argv[1]) if l.startswith("SIM RESULT")]
d = json.loads(lines[-1][len("SIM RESULT "):])
assert d.get("unknown_ops", 0) >= 1, "unimplemented op not reported honestly"
assert "phase_defaults_none" in d.get("asserts_ok", []), "basic state assert failed"
print("transport ok")
PYEOF
say "US-101 PASS: transport live"
exit 0
