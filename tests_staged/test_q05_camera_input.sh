#!/bin/bash
# US-Q05 — camera constants, input matrix (keyboard + gamepad probes),
# portrait HUD safety, occlusion rule.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate

bash "$(dirname "${BASH_SOURCE[0]}")/probe_input_keyboard.sh" || die "keyboard probe failed"
bash "$(dirname "${BASH_SOURCE[0]}")/probe_input_gamepad.sh" || die "gamepad probe failed"

CMDS="$(mktemp /tmp/grindline_cmds_q05_XXXX.json)"
cat > "$CMDS" <<'JSON'
{
  "seed": 3,
  "steps": [
    {"op": "start", "mode": "run"},
    {"op": "input", "action": "push", "held_ms": 2000},
    {"op": "seekMs", "ms": 400},
    {"op": "probe", "name": "fov_base_62", "kind": "camera_fov", "expect": 62},
    {"op": "seekMs", "ms": 2500},
    {"op": "probe", "name": "fov_kick_speed", "kind": "camera_fov_at_speed", "speed": 10, "expect_min": 70},
    {"op": "viewport", "w": 390, "h": 844},
    {"op": "setUi", "id": "touch_overlay"},
    {"op": "seekMs", "ms": 500},
    {"op": "screenshot", "id": "mobile"},
    {"op": "probe", "name": "touch_targets_96px", "kind": "ui_targets", "min_px": 96},
    {"op": "probe", "name": "safe_area", "kind": "hud_safe_area"},
    {"op": "viewport", "w": 1280, "h": 720},
    {"op": "teleport", "zone": "warehouse_corridor"},
    {"op": "input", "action": "push", "held_ms": 1500},
    {"op": "seekMs", "ms": 1600},
    {"op": "assert", "name": "occlusion_hug", "expr": "camera.distance <= 2.65 and skater.on_screen == true"}
  ],
  "gate": true
}
JSON

run_sim "$CMDS" || die "sim exited non-zero"
assert_sim_json "d.get('pass') is True"
[[ -s "$SHOTS_DIR/mobile.png" ]] || die "missing shots/mobile.png"
png_check "$SHOTS_DIR/mobile.png" 390 844
say "US-Q05 PASS: camera, inputs, portrait and occlusion proven"
exit 0
