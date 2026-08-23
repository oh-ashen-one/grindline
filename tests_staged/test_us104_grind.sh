#!/bin/bash
# US-104 — grind latch + balance meter discipline on the flat rail.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate
CMDS="$(mktemp -t grindline)"
cat > "$CMDS" <<'JSON'
{
  "seed": 3,
  "steps": [
    {"op": "start", "mode": "run"},
    {"op": "teleport", "zone": "rail_approach"},
    {"op": "input", "action": "push", "held_ms": 550},
    {"op": "input", "action": "ollie", "held_ms": 60},
    {"op": "probe", "name": "latch_wait", "kind": "max_path_value_between_ms", "path": "grind.active", "ms": 1200, "min": 0.5, "max": 999},
    {"op": "assert", "name": "latched_grind", "state": "skater.state == 'grind'"},
    {"op": "probe", "name": "lateral_snap", "kind": "scalar_lte", "path": "grind.lateral_offset", "value": 0.15},
    {"op": "probe", "name": "meter_decays", "kind": "lt_prev", "path": "balance.value", "ms": 500},
    {"op": "input", "action": "correct_hold", "held_ms": 2000},
    {"op": "probe", "name": "meter_held_band", "kind": "path_in_range_ms", "path": "balance.value", "ms": 2000, "min": 0.06, "max": 0.94}
  ],
  "gate": true
}
JSON
run_sim "$CMDS" || die "sim failed"
assert_sim_json "'latched_grind' in d.get('asserts_ok', [])"
assert_sim_json "'meter_held_band' in d.get('probes_ok', [])"
say "US-104 PASS: grind latch and balance to spec"
exit 0
