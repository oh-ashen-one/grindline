#!/bin/bash
# US-Q03 — asset integration: manifest-complete loading, measured extents,
# clip mapping, and fallback degradation.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate

# 1) static extents check straight from the registry + measurements
python3 - <<'PYEOF' || die "extents mismatch"
import json, sys
root = "."
man = json.load(open("assets/asset-manifest.json"))
met = json.load(open("game/data/asset_metrics.json"))
checked = 0
for a in man["assets"]:
    if a["category"] in ("environment", "prop", "character"):
        key = a["path"]
        assert key in met, f"no metrics for {key}"
        v = met[key]
        mn, mx = v["boundsMin"], v["boundsMax"]
        ext = [mx[i] - mn[i] for i in range(3)]
        tgt = a["targetSizeMeters"]
        for i in range(3):
            if abs(ext[i] - tgt[i]) > max(0.35, tgt[i] * 0.06):
                print(f"EXTENT MISMATCH {a['id']}: glb {ext} vs target {tgt}")
                sys.exit(1)
        checked += 1
print(f"static extents ok for {checked} assets")
PYEOF

CMDS="$(mktemp /tmp/grindline_cmds_q03_XXXX.json)"
cat > "$CMDS" <<'JSON'
{
  "seed": 3,
  "steps": [
    {"op": "start", "mode": "run"},
    {"op": "seekMs", "ms": 1500},
    {"op": "probe", "name": "manifest_load_complete", "kind": "adapter_report"},
    {"op": "probe", "name": "clips_mapped", "kind": "clip_report"},
    {"op": "screenshot", "id": "q03_full_park"}
  ],
  "gate": true
}
JSON

run_sim "$CMDS" || die "sim exited non-zero"
assert_sim_json "d.get('probes', {}).get('manifest_load_complete') == 'ok'"
assert_sim_json "d.get('probes', {}).get('clips_mapped') == 'ok'"
assert_sim_json "int(d.get('draw_calls', 9999)) <= 220"

# 2) fallback degradation: hide board GLB, expect degraded flag + still playable
mv assets/models/board/skateboard.glb /tmp/skateboard.glb.bak
trap 'mv /tmp/skateboard.glb.bak assets/models/board/skateboard.glb 2>/dev/null || true' EXIT
"$GODOT_BIN" --headless --path "$GRINDLINE_ROOT" res://game/sim/sim_bridge.tscn \
  -- "--cmds=$CMDS" "--shots=$SHOTS_DIR" --expect-degraded >"$SIM_OUT" 2>&1 || \
  die "sim failed under missing-asset condition"
assert_sim_json "d.get('degraded') is True and d.get('playable') is True"
say "US-Q03 PASS: integration complete with honest fallbacks"
exit 0
