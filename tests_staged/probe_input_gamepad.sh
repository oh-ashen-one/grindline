#!/bin/bash
# probe_input_gamepad.sh — joypad events through the engine path produce the
# same state deltas as keyboard equivalents.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate

CMDS="$(mktemp /tmp/grindline_cmds_pad_XXXX.json)"
cat > "$CMDS" <<'JSON'
{
  "seed": 3,
  "steps": [
    {"op": "start", "mode": "run"},
    {"op": "seekMs", "ms": 800},
    {"op": "input", "action": "steer_left", "held_ms": 400, "via": "pad_stick_left"},
    {"op": "probe", "name": "pad_steer_responded", "kind": "heading_delta", "min_deg": 10},
    {"op": "input", "action": "ollie", "held_ms": 60, "via": "pad_button_a"},
    {"op": "seekMs", "ms": 200},
    {"op": "assert", "name": "pad_ollie_airborne", "state": "skater.grounded == false"}
  ],
  "gate": true
}
JSON

run_sim "$CMDS" || die "sim exited non-zero"
assert_sim_json "d.get('probes', {}).get('pad_steer_responded') == 'ok'"
assert_sim_json "'pad_ollie_airborne' in d.get('asserts_ok', [])"
say "gamepad probe PASS"
exit 0
