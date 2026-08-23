#!/bin/bash
# US-103 — ollie impulse, air state, landing.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate
CMDS="$(mktemp /tmp/gl_cmds_103_XXXX.json)"
cat > "$CMDS" <<'JSON'
{
  "seed": 3,
  "steps": [
    {"op": "start", "mode": "run"},
    {"op": "seekMs", "ms": 500},
    {"op": "input", "action": "push", "held_ms": 800},
    {"op": "input", "action": "ollie", "held_ms": 60},
    {"op": "assert", "name": "airborne_same_tick", "state": "skater.grounded == false"},
    {"op": "probe", "name": "apex_height", "kind": "max_path_value_between_ms", "path": "skater.height", "ms": 900, "min": 1.2, "max": 1.5},
    {"op": "seekMs", "ms": 1200},
    {"op": "assert", "name": "regrounded", "state": "skater.grounded == true"}
  ],
  "gate": true
}
JSON
run_sim "$CMDS" || die "sim failed"
assert_sim_json "'airborne_same_tick' in d.get('asserts_ok', [])"
assert_sim_json "'apex_height' in d.get('probes_ok', [])"
say "US-103 PASS: ollie to spec"
exit 0
