#!/bin/bash
# US-105 — run model: timer exactness, scoring, bail reset, expiry phase.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate
CMDS="$(mktemp /tmp/gl_cmds_105_XXXX.json)"
cat > "$CMDS" <<'JSON'
{
  "seed": 3,
  "steps": [
    {"op": "start", "mode": "run"},
    {"op": "seekMs", "ms": 1000},
    {"op": "probe", "name": "timer_exact", "kind": "approx_path", "path": "run.time_left_ms", "value": 119000, "tol": 34},
    {"op": "input", "action": "push", "held_ms": 600},
    {"op": "input", "action": "ollie", "held_ms": 60},
    {"op": "seekMs", "ms": 1100},
    {"op": "probe", "name": "scored_once", "kind": "approx_path", "path": "run.combo_count", "value": 1, "tol": 0.5},
    {"op": "input", "action": "bail_force", "held_ms": 10},
    {"op": "probe", "name": "multiplier_reset", "kind": "approx_path", "path": "run.multiplier", "value": 1, "tol": 0.01},
    {"op": "seekMs", "ms": 118000},
    {"op": "assert", "name": "results_phase", "state": "run.phase == 'results'"}
  ],
  "gate": true
}
JSON
run_sim "$CMDS" || die "sim failed"
assert_sim_json "d.get('pass') is True"
assert_sim_json "'results_phase' in d.get('asserts_ok', [])"
say "US-105 PASS: run model exact"
exit 0
