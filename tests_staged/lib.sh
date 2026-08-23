#!/bin/bash
# tests_staged/lib.sh — manager-owned verify helpers (law 15). Tests are the
# spec; game code makes them pass. Never edit a test to make code pass.
set -euo pipefail
GRINDLINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/opt/homebrew/bin/godot}"
SHOTS_DIR="$GRINDLINE_ROOT/shots"
SIM_OUT="$GRINDLINE_ROOT/.sim_last_output.txt"

say()  { echo "[verify] $*"; }
die()  { echo "[verify] FAIL: $*" >&2; exit 1; }

require_godot() {
  [[ -x "$GODOT_BIN" ]] || die "godot binary not found at $GODOT_BIN"
  [[ -f "$GRINDLINE_ROOT/project.godot" ]] || die "project.godot not created yet — spec cannot be evaluated pre-phase-1 (RED)"
}

# import parse gate: zero errors allowed before anything else
import_gate() {
  local log
  log=$("$GODOT_BIN" --headless --path "$GRINDLINE_ROOT" --import 2>&1) || true
  if echo "$log" | grep -qiE "SCRIPT ERROR|Parse Error|Failed to load"; then
    echo "$log" | grep -iE "SCRIPT ERROR|Parse Error|Failed to load" | head -10
    die "import gate reported errors"
  fi
  return 0
}

# run_sim <commands-json-file> [extra args...]
# Drives game/sim/sim_bridge.gd (the deterministic QA transport, SceneTree
# script mode). Extra args pass through (e.g. --expect-degraded).
run_sim() {
  local cmds="$1"; shift || true
  [[ -f "$GRINDLINE_ROOT/game/sim/sim_bridge.gd" ]] || die "missing game/sim/sim_bridge.gd"
  mkdir -p "$SHOTS_DIR"
  "$GODOT_BIN" --headless --path "$GRINDLINE_ROOT" --script res://game/sim/sim_bridge.gd \
    -- "--cmds=$cmds" "--shots=$SHOTS_DIR" "$@" >"$SIM_OUT" 2>&1
  local rc=$?
  grep -E "SIM RESULT|SIM ASSERT|SIM ERROR" "$SIM_OUT" | tail -40 || true
  return $rc
}

# run_sim_gfx — windowed variant for pixel-producing captures.
run_sim_gfx() {
  local cmds="$1"; shift || true
  [[ -f "$GRINDLINE_ROOT/game/sim/sim_bridge.gd" ]] || die "missing game/sim/sim_bridge.gd"
  mkdir -p "$SHOTS_DIR"
  "$GODOT_BIN" --path "$GRINDLINE_ROOT" --script res://game/sim/sim_bridge.gd \
    -- "--cmds=$cmds" "--shots=$SHOTS_DIR" "$@" >"$SIM_OUT" 2>&1
  local rc=$?
  grep -E "SIM RESULT|SIM ASSERT|SIM ERROR" "$SIM_OUT" | tail -40 || true
  return $rc
}

# assert_sim_json <python-expr over parsed SIM RESULT dict as d>
assert_sim_json() {
  python3 - "$SIM_OUT" "$1" <<'PYEOF'
import json, re, sys
lines = open(sys.argv[1]).read().splitlines()
results = []
for ln in lines:
    m = re.match(r"SIM RESULT (\{.*\})", ln.strip())
    if m:
        results.append(json.loads(m.group(1)))
ok = False
for d in results:
    try:
        if eval(sys.argv[2], {}, {"d": d}):
            ok = True
            break
    except Exception:
        pass
print(f"assert_sim_json: {sys.argv[2]} -> {ok}")
sys.exit(0 if ok else 1)
PYEOF
}

# png_exists_and_size <path> <w> <h>
png_check() {
  python3 - "$@" <<'PYEOF'
import struct, sys
p, w, h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
with open(p, "rb") as f:
    head = f.read(33)
assert head[:8] == b"\x89PNG\r\n\x1a\n", f"{p}: not a PNG"
pw, ph = struct.unpack(">II", head[16:24])
assert (pw, ph) == (w, h), f"{p}: {pw}x{ph}, want {w}x{h}"
print(f"png_check ok {p}")
PYEOF
}
