#!/bin/zsh
set -eu
cd "${0:A:h:h}"
build_dir="/private/tmp/mellow-release-build"
xcodebuild -quiet -project Mellow.xcodeproj -scheme Mellow -configuration Release \
    -derivedDataPath "$build_dir" CODE_SIGNING_ALLOWED=NO build
# Finder info / provenance attributes make a strict signature check fail.
xattr -cr "$build_dir/Build/Products/Release/Mellow.app"
# Sign with the Developer ID certificate when it is in the keychain (needed to run on other Macs),
# otherwise ad-hoc for local use. Override with SIGN_IDENTITY="…".
identity=${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)}
if [[ -n $identity ]]; then
    codesign --force --options runtime --timestamp --sign "$identity" "$build_dir/Build/Products/Release/Mellow.app"
else
    codesign --force --options runtime --sign - "$build_dir/Build/Products/Release/Mellow.app"
fi
mkdir -p Build
# Replace only this generated app bundle; merging bundles leaves obsolete signed files.
if [[ -d Build/Mellow.app ]]; then rm -rf Build/Mellow.app; fi
ditto --norsrc --noextattr "$build_dir/Build/Products/Release/Mellow.app" Build/Mellow.app
codesign --verify --deep --strict Build/Mellow.app
print "Ready: $PWD/Build/Mellow.app"
