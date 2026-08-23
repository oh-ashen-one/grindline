#!/bin/bash
# export_macos.sh — package GRINDLINE as a macOS .app via Godot export presets.
# Requires Godot export templates installed once:
#   godot --headless --install-templates-and-exit   (or via editor UI)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/opt/homebrew/bin/godot}"
OUT="$ROOT/build"
mkdir -p "$OUT"

if ! ls "$HOME/Library/Application Support/Godot/export_templates" >/dev/null 2>&1; then
  echo "export templates missing — install them first:" >&2
  echo "  $GODOT_BIN --headless --install-templates-and-exit" >&2
  exit 3
fi

# minimal preset if absent
if [[ ! -f "$ROOT/export_presets.cfg" ]]; then
cat > "$ROOT/export_presets.cfg" <<'CFG'
[preset.0]
name="macOS"
platform="macOS"
runnable=true
export_filter="all_resources"
[preset.0.options]
binary_format/architecture="arm64"
EOF
fi

"$GODOT_BIN" --headless --path "$ROOT" --export-release "macOS" "$OUT/grindline.app" 2>&1 | tail -5
[[ -x "$OUT/grindline.app/Contents/MacOS/grindline" ]] || {
  # binary name can differ by version; locate any executable
  BIN=$(find "$OUT/grindline.app/Contents/MacOS" -type f 2>/dev/null | head -1 || true)
  [[ -n "$BIN" ]] && echo "exported: $BIN" && exit 0
  echo "export produced no executable" >&2
  exit 1
}
echo "exported: $OUT/grindline.app"
