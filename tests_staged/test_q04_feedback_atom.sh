#!/bin/bash
# US-Q04 — feedback atoms: ollie/grind/bail beats on all five channels inside
# contract windows; pool discipline under a 60 s trick soak.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate

CMDS="$(mktemp -t grindline)"
cat > "$CMDS" <<'JSON'
{
  "seed": 3,
  "steps": [
    {"op": "start", "mode": "run"},
    {"op": "seekMs", "ms": 1000},
    {"op": "beat", "id": "ollie-beat"},
    {"op": "beat", "id": "grind-beat"},
    {"op": "beat", "id": "bail-beat"},
    {"op": "soak", "ms": 60000, "script": "trick_loop"},
    {"op": "probe", "name": "pool_discipline", "kind": "pool_report"}
  ],
  "gate": true
}
JSON

run_sim "$CMDS" || die "sim exited non-zero"
assert_sim_json "d.get('pass') is True"
assert_sim_json "'ollie-beat' in d.get('beats_ok', [])"
assert_sim_json "'grind-beat' in d.get('beats_ok', [])"
assert_sim_json "'bail-beat' in d.get('beats_ok', [])"
assert_sim_json "d.get('pool_discipline') == 'ok'"
say "US-Q04 PASS: all three beats complete within windows"
exit 0
