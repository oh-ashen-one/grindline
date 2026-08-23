#!/bin/bash
# US-201 — dusk lighting rig values, measured through the live scene.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate
CMDS="$(mktemp -t grindline)"
cat > "$CMDS" <<'JSON'
{
  "seed": 3,
  "steps": [
    {"op": "start", "mode": "run"},
    {"op": "seekMs", "ms": 300},
    {"op": "probe", "name": "env_report", "kind": "env_report"}
  ],
  "gate": true
}
JSON
run_sim "$CMDS" || die "sim failed"
assert_sim_json "d.get('probes', {}).get('env_report') == 'ok'"
say "US-201 PASS: dusk rig live"
exit 0
