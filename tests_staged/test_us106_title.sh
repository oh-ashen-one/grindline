#!/bin/bash
# US-106 — cold boot reaches title with Bebas wordmark.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate
CMDS="$(mktemp /tmp/gl_cmds_106_XXXX.json)"
cat > "$CMDS" <<'JSON'
{
  "seed": 1,
  "steps": [
    {"op": "assert", "name": "at_title", "state": "app.phase == 'title'"},
    {"op": "probe", "name": "wordmark_bebas", "kind": "font_region", "region": [40, 40, 620, 240]},
    {"op": "probe", "name": "press_start_chip", "kind": "ui_min_height", "node": "PressStart", "min_px": 48},
    {"op": "screenshot", "id": "us106_title"}
  ],
  "gate": true
}
JSON
run_sim "$CMDS" || die "sim failed"
assert_sim_json "'at_title' in d.get('asserts_ok', [])"
assert_sim_json "d.get('probes', {}).get('wordmark_bebas') == 'ok'"
say "US-106 PASS: title state live"
exit 0
