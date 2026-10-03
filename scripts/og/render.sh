#!/bin/zsh
# Renders the touch icon and favicon. The social card (website/og-image.jpg) is exported
# from the Figma frame "Meta image · 1200×600".
#   zsh scripts/og/render.sh
set -eu
cd "${0:A:h}"
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
out=$(mktemp -d /private/tmp/mellow-og.XXXXXX)
shot() { "$chrome" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
    --window-size="$2" --screenshot="$out/$3" "file://$PWD/$1" >/dev/null 2>&1; }

shot icon.html 180,180 icon@2x.png
sips -z 180 180 "$out/icon@2x.png" --out ../../website/apple-touch-icon.png >/dev/null
sips -z 32 32 ../../website/assets/logo.png --out ../../website/favicon-32.png >/dev/null

rm -rf "$out"
print "Ready: website/apple-touch-icon.png, website/favicon-32.png"
