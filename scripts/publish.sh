#!/bin/zsh
# Publishes the notarized DMG to the Cloudflare R2 bucket the website downloads from.
# Mellow.dmg is always the newest version (saved as Mellow-<version>.dmg in the browser),
# and latest.json tells the website which version that is.
#   zsh scripts/publish.sh                       # after scripts/release.sh
#   zsh scripts/publish.sh Build/Mellow-1.1.dmg  # a specific DMG
set -eu
cd "${0:A:h:h}"
bucket=${R2_BUCKET:-mellow-downloads}
base=${R2_PUBLIC_URL:-https://pub-b692e0bf9c0b436f87e42a33288b264b.r2.dev}
dmg=${1:-}
if [[ -z $dmg ]]; then
    version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Build/Mellow.app/Contents/Info.plist)
    dmg="Build/Mellow-$version.dmg"
else
    version=${${dmg:t}#Mellow-}
    version=${version%.dmg}
fi
if [[ ! -f $dmg ]]; then print -u2 "No DMG at $dmg. Run scripts/release.sh first."; exit 1; fi

# Refuse to ship an app that Gatekeeper would block on other Macs.
mnt=$(mktemp -d /private/tmp/mellow-publish.XXXXXX)
hdiutil attach -nobrowse -readonly -mountpoint "$mnt" "$dmg" >/dev/null
trap 'hdiutil detach -quiet "$mnt" 2>/dev/null || true' EXIT
xcrun stapler validate "$mnt/Mellow.app" >/dev/null
spctl --assess --type execute "$mnt/Mellow.app"
hdiutil detach -quiet "$mnt"
trap - EXIT

r2put() { npx -y wrangler@4 r2 object put "$bucket/$1" --remote --file "$2" "${@:3}"; }
print "Uploading Mellow $version…"
r2put Mellow.dmg "$dmg" --content-type application/x-apple-diskimage \
    --content-disposition "attachment; filename=\"Mellow-$version.dmg\"" --cache-control "no-cache"
json=$(mktemp /private/tmp/mellow-latest.XXXXXX)
print -r -- "{\"version\": \"$version\", \"url\": \"$base/Mellow.dmg\", \"size\": $(stat -f %z "$dmg"), \"published\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > "$json"
r2put latest.json "$json" --content-type application/json --cache-control "no-cache"
rm -f "$json"
print "Published: $base/Mellow.dmg (version $version)"
