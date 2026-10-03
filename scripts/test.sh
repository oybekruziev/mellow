#!/bin/zsh
set -eu
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH=/private/tmp/mellow-module-cache
export SWIFT_MODULECACHE_PATH=/private/tmp/mellow-module-cache
swift test --disable-sandbox --scratch-path /private/tmp/mellow-core-build \
    --cache-path /private/tmp/mellow-pm-cache --config-path /private/tmp/mellow-pm-config \
    --security-path /private/tmp/mellow-pm-security
