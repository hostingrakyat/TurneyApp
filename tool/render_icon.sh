#!/usr/bin/env bash
# Rasterize the ProTourney mark (branding/logo-mark.svg) into the 1024px PNG
# that flutter_launcher_icons consumes. Uses headless Chromium so no extra
# image tooling is required. Re-run after changing the logo, then:
#   cd app && dart run flutter_launcher_icons
set -euo pipefail
cd "$(dirname "$0")/.."

CHROME="${CHROME:-/opt/pw-browsers/chromium}"
OUT="app/assets/icons/app_icon.png"
TMP="$(mktemp -d)"

cat > "$TMP/icon.html" <<HTML
<!doctype html><html><head><meta charset="utf-8"><style>
  html,body{margin:0;padding:0;width:1024px;height:1024px;background:#6E1422;}
  .wrap{width:1024px;height:1024px;display:flex;align-items:center;justify-content:center;}
  img{width:1024px;height:1024px;}
</style></head><body>
  <div class="wrap"><img src="file://$PWD/branding/logo-mark.svg"></div>
</body></html>
HTML

mkdir -p app/assets/icons
"$CHROME" --headless --no-sandbox --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=1 --window-size=1024,1024 \
  --screenshot="$PWD/$OUT" "file://$TMP/icon.html"
echo "Wrote $OUT"
