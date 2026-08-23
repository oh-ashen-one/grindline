#!/bin/bash
# US-Q06 — worst-scene performance budgets + degradation ladder.
# Headless measures logic-side frame cost (see BRIEF honest limitations);
# GPU thermals and feel remain human-playtest items (law 12).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate

CMDS="$(mktemp -t grindline)"
cat > "$CMDS" <<'JSON'
{
  "seed": 7,
  "steps": [
    {"op": "start", "mode": "run_worst"},
    {"op": "soak", "ms": 10000},
    {"op": "probe", "name": "budgets", "kind": "budgets_probe", "expect_level": 0}
  ],
  "gate": true
}
JSON

run_sim "$CMDS" || die "soak sim failed"
assert_sim_json "d.get('pass') is True"
assert_sim_json "float(d.get('median_frame_ms', 999)) <= 17.0"
assert_sim_json "int(d.get('draw_calls', 9999)) <= 220"
assert_sim_json "int(d.get('active_objects', 99999)) <= 900"

CMDS2="$(mktemp -t grindline)"
cat > "$CMDS2" <<'JSON'
{
  "seed": 7,
  "steps": [
    {"op": "start", "mode": "run_worst"},
    {"op": "degrade", "level": 1},
    {"op": "seekMs", "ms": 500},
    {"op": "probe", "name": "degrade_l1", "kind": "degrade_report"}
  ],
  "gate": true
}
JSON
run_sim "$CMDS2" || die "degrade sim failed"
assert_sim_json "d.get('probes', {}).get('degrade_l1') == 'ok'"
say "US-Q06 PASS: budgets held; degradation ladder verified"
exit 0
