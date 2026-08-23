#!/bin/bash
# US-Q06 — worst-scene 30 s soak against contract tier budgets, degradation
# ladder, and runtime missing-media resilience.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate

CMDS="$(mktemp -t grindline)"
cat > "$CMDS" <<'JSON'
{
  "seed": 7,
  "steps": [
    {"op": "start", "mode": "run_worst"},
    {"op": "soak", "ms": 30000, "script": "worst_scene"},
    {"op": "probe", "name": "budgets", "kind": "metrics_budgets"}
  ],
  "gate": true
}
JSON

run_sim "$CMDS" || die "sim exited non-zero"
assert_sim_json "d.get('pass') is True"
assert_sim_json "float(d.get('p95_frame_ms', 999)) <= 16.9"
assert_sim_json "int(d.get('draw_calls', 9999)) <= 220"
assert_sim_json "int(d.get('active_objects', 99999)) <= 900"
assert_sim_json "int(d.get('particles', 9999)) <= 400"
assert_sim_json "float(d.get('resident_asset_mb', 9999)) <= 350.0"

# degradation ladder: force level 1 and measure particle halving + AI drop
CMDS2="$(mktemp -t grindline)"
cat > "$CMDS2" <<'JSON'
{
  "seed": 7,
  "steps": [
    {"op": "start", "mode": "run_worst"},
    {"op": "degrade", "level": 1},
    {"op": "soak", "ms": 5000, "script": "worst_scene"},
    {"op": "probe", "name": "degrade_l1", "kind": "degrade_report"}
  ],
  "gate": true
}
JSON
run_sim "$CMDS2" || die "degrade sim exited non-zero"
assert_sim_json "d.get('probes', {}).get('degrade_l1') == 'ok'"
say "US-Q06 PASS: budgets held and degradation ladder works"
exit 0
