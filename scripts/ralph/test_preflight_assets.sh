#!/bin/bash
# Red/green test for law-16 asset launch gate, including native iOS USDZ.
set -euo pipefail

TMP_ROOT=$(mktemp -d)
PROJECT="$TMP_ROOT/game"
trap 'rm -rf "$TMP_ROOT"' EXIT
mkdir -p "$PROJECT/scripts/ralph" "$PROJECT/assets"

printf '# Brief\n\n## Asset models\nLicensed USDZ character and environment pack.\n' \
  > "$PROJECT/scripts/ralph/BRIEF.md"
touch "$PROJECT/assets/hero.usdz" "$PROJECT/assets/environment.usdz" "$PROJECT/assets/prop.usdz"
cat > "$PROJECT/assets/ASSET-MANIFEST.md" <<MANIFEST
# Assets

Source: https://example.test/pack
License: CC0

- $PROJECT/assets/hero.usdz
- $PROJECT/assets/environment.usdz
- $PROJECT/assets/prop.usdz
MANIFEST

bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/preflight_assets.sh" "$PROJECT" >/dev/null

rm "$PROJECT/assets/prop.usdz"
if bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/preflight_assets.sh" "$PROJECT" >/dev/null 2>&1; then
  echo "test_preflight_assets: expected missing declared USDZ to block" >&2
  exit 1
fi

echo "test_preflight_assets: OK"
