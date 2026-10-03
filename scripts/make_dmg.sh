#!/bin/zsh
# Packs Build/Mellow-<version>.dmg (Mellow.app + Applications shortcut).
#   zsh scripts/make_dmg.sh               # local Release build first (Developer ID signed, not notarized)
#   zsh scripts/make_dmg.sh --skip-build  # pack the Build/Mellow.app already there (release.sh uses this)
set -eu
cd "${0:A:h:h}"
if [[ ${1:-} != --skip-build ]]; then zsh scripts/build.sh; fi
version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Build/Mellow.app/Contents/Info.plist)
stage=$(mktemp -d /private/tmp/mellow-dmg.XXXXXX)
ditto --norsrc --noextattr Build/Mellow.app "$stage/Mellow.app"
ln -s /Applications "$stage/Applications"
dmg="Build/Mellow-$version.dmg"
if [[ -f $dmg ]]; then rm "$dmg"; fi
hdiutil create -volname "Mellow" -srcfolder "$stage" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$dmg" >/dev/null
rm -rf "$stage"
hdiutil verify "$dmg" >/dev/null
print "Ready: $PWD/$dmg"
