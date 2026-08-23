#!/bin/bash
# US-Q02 — look lock: canonical frames at ship bar. Palette separation,
# silhouette contrast, HUD font discipline are measured by the sim's own
# pixel probes (headless rendering) and cross-checked here.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate

CMDS="$(mktemp -t grindline)"
cat > "$CMDS" <<'JSON'
{
  "seed": 1,
  "steps": [
    {"op": "setUi", "id": "menu"},
    {"op": "setCamera", "id": "menu_orbit"},
    {"op": "seekMs", "ms": 1500},
    {"op": "screenshot", "id": "title"},
    {"op": "probe", "name": "hud_font_bebas", "kind": "font_region", "region": [40, 40, 620, 200]},
    {"op": "start", "mode": "run"},
    {"op": "setCamera", "id": "follow_action"},
    {"op": "input", "action": "push", "held_ms": 900},
    {"op": "input", "action": "ollie", "held_ms": 60},
    {"op": "seekMs", "ms": 300},
    {"op": "screenshot", "id": "primary-action"},
    {"op": "probe", "name": "dusk_sky_cluster", "kind": "color_cluster", "hex": "#e06040", "min_pixels": 400},
    {"op": "probe", "name": "steel_metal_cluster", "kind": "color_cluster", "hex": "#cfd2d6", "min_pixels": 150},
    {"op": "probe", "name": "silhouette_contrast", "kind": "luma_contrast", "min_delta_pct": 35}
  ],
  "gate": true
}
JSON

run_sim_gfx "$CMDS" || die "sim exited non-zero"
assert_sim_json "d.get('pass') is True"
[[ -s "$SHOTS_DIR/title.png" ]] || die "missing shots/title.png"
[[ -s "$SHOTS_DIR/primary-action.png" ]] || die "missing shots/primary-action.png"
png_check "$SHOTS_DIR/title.png" 1280 720
png_check "$SHOTS_DIR/primary-action.png" 1280 720
assert_sim_json "d.get('probes', {}).get('hud_font_bebas') == 'ok'"
assert_sim_json "d.get('probes', {}).get('silhouette_contrast') == 'ok'"
say "US-Q02 PASS: look-lock frames at ship bar"
exit 0
