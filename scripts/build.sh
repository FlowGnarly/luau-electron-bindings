#!/bin/sh

set -e

scripts/build-single-file.sh .darklua-bundle.json build/luau-electron-bindings.luau
scripts/build-single-file.sh .darklua-bundle-dev.json build/debug/luau-electron-bindings.luau
