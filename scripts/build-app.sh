#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/baidunetdisk-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/tmp}/baidunetdisk-swift-cache"
swift build -c release
BIN_DIR=$(swift build -c release --show-bin-path)
APP="dist/BaiduNetDisk.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/BaiduNetDisk" "$APP/Contents/MacOS/BaiduNetDisk"
cp scripts/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"
