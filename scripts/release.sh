#!/bin/zsh
# Notarized release: archive → Developer ID export uploaded to Apple's notary service
# (through the Apple account signed in to Xcode, no password needed) → stapled app → DMG.
#   zsh scripts/release.sh            # notarized DMG in Build/
#   zsh scripts/release.sh --publish  # …and put it behind bemellow.cc's Download button
set -eu
publish=false
[[ ${1:-} == --publish ]] && publish=true
cd "${0:A:h:h}"
team=${TEAM_ID:-79CTV95T7T}
work=/private/tmp/mellow-release
rm -rf "$work"; mkdir -p "$work"
cat > "$work/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>method</key><string>developer-id</string>
    <key>destination</key><string>upload</string>
    <key>teamID</key><string>$team</string>
    <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
print "Archiving…"
xcodebuild -quiet archive -project Mellow.xcodeproj -scheme Mellow -configuration Release \
    -archivePath "$work/Mellow.xcarchive" -destination 'generic/platform=macOS' \
    DEVELOPMENT_TEAM="$team" CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates
print "Uploading for notarization…"
xcodebuild -exportArchive -archivePath "$work/Mellow.xcarchive" -exportOptionsPlist "$work/ExportOptions.plist" \
    -exportPath "$work/upload" -allowProvisioningUpdates 2>&1 | grep -E "Uploaded|EXPORT|error" || true
print "Waiting for Apple…"
for attempt in {1..40}; do
    if xcodebuild -exportNotarizedApp -archivePath "$work/Mellow.xcarchive" -exportPath "$work/notarized" >/dev/null 2>&1; then break; fi
    if (( attempt == 40 )); then print "Notarization did not finish in 20 minutes."; exit 1; fi
    sleep 30
done
xcrun stapler validate "$work/notarized/Mellow.app"
spctl --assess --type execute "$work/notarized/Mellow.app"
mkdir -p Build
if [[ -d Build/Mellow.app ]]; then rm -rf Build/Mellow.app; fi
ditto --norsrc --noextattr "$work/notarized/Mellow.app" Build/Mellow.app
zsh scripts/make_dmg.sh --skip-build
# Uses this Mac's wrangler login, so no Cloudflare token has to live on GitHub.
if $publish; then zsh scripts/publish.sh; fi
