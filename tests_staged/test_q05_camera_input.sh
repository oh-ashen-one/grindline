#!/bin/bash
# US-Q05 — camera constants, input matrix (keyboard + gamepad probes),
# portrait HUD safety, occlusion rule.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate

bash "$(dirname "${BASH_SOURCE[0]}")/probe_input_keyboard.sh" || die "keyboard probe failed"
bash "$(dirname "${BASH_SOURCE[0]}")/probe_input_gamepad.sh" || die "gamepad probe failed"

CMDS="$(mktemp -t grindline)"
cat > "$CMDS" <<'JSON'
{
  "seed": 3,
  "steps": [
    {"op": "start", "mode": "run"},
    {"op": "probe", "name": "fov_base_62", "kind": "camera_fov", "expect": 62},
    {"op": "input", "action": "push", "held_ms": 2000},
    {"op": "probe", "name": "fov_kick_speed", "kind": "camera_fov_at_speed", "speed": 10, "expect_min": 70},
    {"op": "setUi", "id": "touch_overlay"},
    {"op": "probe", "name": "touch_targets_96px", "kind": "ui_targets", "min_px": 96},
    {"op": "probe", "name": "safe_area", "kind": "hud_safe_area"},
    {"op": "occlusion_case", "name": "occl_blocked", "from": [0, 1.45, 14], "to": [0, 2.97, 8], "expect_clamped": true}
  ],
  "gate": true
}
JSON

run_sim "$CMDS" || die "sim exited non-zero"
assert_sim_json "d.get('pass') is True"
[[ -s "$SHOTS_DIR/mobile.png" ]] || die "missing shots/mobile.png"
png_check "$SHOTS_DIR/mobile.png" 390 844
CMDS2="$(mktemp -t grindline)"
cat > "$CMDS2" <<'JSON2'
{
  "seed": 3,
  "steps": [
    {"op": "start", "mode": "run"},
    {"op": "viewport", "w": 390, "h": 844},
    {"op": "setUi", "id": "touch_overlay"},
    {"op": "seekMs", "ms": 400},
    {"op": "screenshot", "id": "mobile"}
  ],
  "gate": false
}
JSON2
run_sim_gfx "$CMDS2" || die "mobile capture failed"
[[ -s "$SHOTS_DIR/mobile.png" ]] || die "missing shots/mobile.png"
png_check "$SHOTS_DIR/mobile.png" 390 844
say "US-Q05 PASS: camera, inputs, portrait and occlusion proven"
exit 0
exit 0
