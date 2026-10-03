#!/bin/zsh
set -eu
cd "${0:A:h:h}"
build_dir="/private/tmp/mellow-release-build"
xcodebuild -project Mellow.xcodeproj -scheme Mellow -configuration Release \
    -derivedDataPath "$build_dir" CODE_SIGNING_ALLOWED=NO build
codesign --force --deep --options runtime --sign - "$build_dir/Build/Products/Release/Mellow.app"
mkdir -p Build
# Replace only this generated app bundle; merging bundles leaves obsolete signed files.
if [[ -d Build/Mellow.app ]]; then rm -rf Build/Mellow.app; fi
ditto "$build_dir/Build/Products/Release/Mellow.app" Build/Mellow.app
codesign --verify --deep Build/Mellow.app
print "Ready: $PWD/Build/Mellow.app"
