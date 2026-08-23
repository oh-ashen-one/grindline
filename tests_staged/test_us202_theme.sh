#!/bin/bash
# US-202 — theme system discipline (fonts, exact colors).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate
CMDS="$(mktemp -t grindline)"
cat > "$CMDS" <<'JSON'
{
  "seed": 1,
  "steps": [
    {"op": "assert", "name": "at_title", "state": "app.phase == 'title'"},
    {"op": "probe", "name": "theme_report", "kind": "theme_report"}
  ],
  "gate": true
}
JSON
run_sim "$CMDS" || die "sim failed"
assert_sim_json "d.get('pass') is True"
assert_sim_json "'at_title' in d.get('asserts_ok', [])"
say "US-202 PASS: theme discipline verified"
exit 0
