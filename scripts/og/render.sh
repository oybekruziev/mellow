#!/bin/zsh
# Renders the social card and touch icon from the HTML sources next to this script.
#   zsh scripts/og/render.sh
set -eu
cd "${0:A:h}"
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
out=$(mktemp -d /private/tmp/mellow-og.XXXXXX)
shot() { "$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
    --window-size="$2" --screenshot="$out/$3" "file://$PWD/$1" >/dev/null 2>&1; }

shot og-card.html 1200,630 og@2x.png
sips -z 630 1200 -s format jpeg -s formatOptions 88 "$out/og@2x.png" --out ../../website/og-image.jpg >/dev/null

shot icon.html 180,180 icon@2x.png
sips -z 180 180 "$out/icon@2x.png" --out ../../website/apple-touch-icon.png >/dev/null
sips -z 32 32 ../../website/assets/logo.png --out ../../website/favicon-32.png >/dev/null

rm -rf "$out"
print "Ready: website/og-image.jpg, website/apple-touch-icon.png, website/favicon-32.png"
