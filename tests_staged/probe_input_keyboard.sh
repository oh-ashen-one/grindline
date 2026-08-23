#!/bin/bash
# probe_input_keyboard.sh — real input events through the engine path.
# Injects InputEventKey via the sim bridge and asserts state deltas.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate

CMDS="$(mktemp -t grindline)"
cat > "$CMDS" <<'JSON'
{
  "seed": 3,
  "steps": [
    {"op": "start", "mode": "run"},
    {"op": "seekMs", "ms": 800},
    {"op": "input", "action": "steer_left", "held_ms": 400, "via": "key_a"},
    {"op": "probe", "name": "kb_steer_responded", "kind": "heading_delta", "min_deg": 10},
    {"op": "input", "action": "ollie", "held_ms": 60, "via": "key_space"},
    {"op": "seekMs", "ms": 200},
    {"op": "assert", "name": "kb_ollie_airborne", "state": "skater.grounded == false"}
  ],
  "gate": true
}
JSON

run_sim "$CMDS" || die "sim exited non-zero"
assert_sim_json "d.get('probes', {}).get('kb_steer_responded') == 'ok'"
assert_sim_json "'kb_ollie_airborne' in d.get('asserts_ok', [])"
say "keyboard probe PASS"
exit 0
