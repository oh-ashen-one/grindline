#!/bin/bash
# probe_ui_touch.sh — portrait viewport with touch overlay: target sizes,
# safe areas, tap-to-ollie through the touch path.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate

CMDS="$(mktemp -t grindline)"
cat > "$CMDS" <<'JSON'
{
  "seed": 3,
  "viewport": [390, 844],
  "steps": [
    {"op": "start", "mode": "run"},
    {"op": "setUi", "id": "touch_overlay"},
    {"op": "seekMs", "ms": 600},
    {"op": "probe", "name": "targets_96px", "kind": "ui_targets", "min_px": 96},
    {"op": "probe", "name": "safe_area", "kind": "hud_safe_area"},
    {"op": "input", "action": "ollie", "held_ms": 40, "via": "touch_tap_right"},
    {"op": "seekMs", "ms": 250},
    {"op": "assert", "name": "touch_ollie_airborne", "state": "skater.grounded == false"}
  ],
  "gate": true
}
JSON

run_sim "$CMDS" || die "sim exited non-zero"
assert_sim_json "d.get('pass') is True"
assert_sim_json "d.get('probes', {}).get('targets_96px') == 'ok'"
say "touch probe PASS"
exit 0
