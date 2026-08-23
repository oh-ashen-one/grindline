#!/bin/bash
# US-102 — push/steer/friction on the flat cell.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate
CMDS="$(mktemp /tmp/gl_cmds_102_XXXX.json)"
cat > "$CMDS" <<'JSON'
{
  "seed": 3,
  "steps": [
    {"op": "start", "mode": "run"},
    {"op": "seekMs", "ms": 500},
    {"op": "input", "action": "push", "held_ms": 2000},
    {"op": "probe", "name": "speed_reached", "kind": "scalar_gte", "path": "skater.speed", "value": 8.0},
    {"op": "probe", "name": "heading_turned", "kind": "heading_delta", "min_deg": 60},
    {"op": "soak", "ms": 3000, "script": "idle"},
    {"op": "probe", "name": "friction_decayed", "kind": "scalar_lte", "path": "skater.speed", "value": 1.0}
  ],
  "gate": true
}
JSON
run_sim "$CMDS" || die "sim failed"
assert_sim_json "'speed_reached' in d.get('probes_ok', [])"
assert_sim_json "'friction_decayed' in d.get('probes_ok', [])"
say "US-102 PASS: locomotion constants verified"
exit 0
