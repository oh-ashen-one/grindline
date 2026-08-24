#!/bin/bash
# US-107 — the real first click: title -> menu -> PLAY -> run, through the
# engine input path, visibly. This is the law-12 spec the loop missed.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
import_gate
CMDS="$(mktemp -t grindline)"
cat > "$CMDS" <<'JSON'
{
  "seed": 1,
  "steps": [
    {"op": "assert", "name": "at_title", "state": "app.phase == 'title'"},
    {"op": "probe", "name": "menu_hidden_at_title", "kind": "node_visible", "node": "MenuLayer", "expect": false},
    {"op": "input", "action": "any_key", "held_ms": 50, "via": "key_space"},
    {"op": "seekMs", "ms": 300},
    {"op": "assert", "name": "menu_shown", "state": "app.phase == 'menu'"},
    {"op": "probe", "name": "menu_visible", "kind": "node_visible", "node": "MenuLayer", "expect": true},
    {"op": "input", "action": "ui_accept", "held_ms": 50, "via": "key_enter"},
    {"op": "seekMs", "ms": 500},
    {"op": "assert", "name": "run_started_from_click", "state": "app.phase == 'running'"},
    {"op": "probe", "name": "menu_gone_in_run", "kind": "node_visible", "node": "MenuLayer", "expect": false},
    {"op": "screenshot", "id": "us107_first_click"}
  ],
  "gate": true
}
JSON
run_sim "$CMDS" || die "sim failed"
assert_sim_json "d.get('pass') is True"
assert_sim_json "'run_started_from_click' in d.get('asserts_ok', [])"
say "US-107 PASS: the first click works"
exit 0
