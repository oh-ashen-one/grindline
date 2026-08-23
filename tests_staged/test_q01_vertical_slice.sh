#!/bin/bash
# US-Q01 — vertical slice: boot -> menu -> run -> ollie score -> timer end ->
# restart. The sim bridge replays the exact input script and reports state
# transitions; this test is the mechanical spec for them.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate

CMDS="$(mktemp /tmp/grindline_cmds_q01_XXXX.json)"
cat > "$CMDS" <<'JSON'
{
  "seed": 3,
  "steps": [
    {"op": "start", "mode": "run"},
    {"op": "seekMs", "ms": 1000},
    {"op": "assert", "name": "in_run", "state": "run.phase == 'running'"},
    {"op": "input", "action": "push", "held_ms": 900},
    {"op": "input", "action": "ollie", "held_ms": 60},
    {"op": "seekMs", "ms": 250},
    {"op": "assert", "name": "airborne", "state": "skater.grounded == false"},
    {"op": "seekMs", "ms": 900},
    {"op": "assert", "name": "landed_scored", "expr": "run.score > 0 and run.combo_count >= 1"},
    {"op": "input", "action": "bail_force", "held_ms": 10},
    {"op": "seekMs", "ms": 1200},
    {"op": "assert", "name": "combo_reset", "expr": "run.multiplier == 1"},
    {"op": "seekMs", "ms": 118000},
    {"op": "assert", "name": "timer_expired", "state": "run.phase == 'results'"},
    {"op": "restart"},
    {"op": "seekMs", "ms": 800},
    {"op": "assert", "name": "restart_clean", "expr": "run.score == 0 and run.time_left_ms >= 119000"},
    {"op": "screenshot", "id": "q01_restart"}
  ],
  "gate": true
}
JSON

run_sim "$CMDS" || die "sim bridge exited non-zero (see $SIM_OUT)"
assert_sim_json "d.get('pass') is True"
assert_sim_json "'airborne' in d.get('asserts_ok', [])"
assert_sim_json "d.get('score_after_ollie', 0) > 0"
say "US-Q01 PASS: vertical slice behaves to spec"
exit 0
