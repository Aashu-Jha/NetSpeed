#!/bin/zsh
# Builds NetSpeed.app.
#   --universal  build a universal binary (arm64 + x86_64) instead of the host architecture
#   --install    copy the app to /Applications and launch it
# Set VERSION (e.g. VERSION=1.2.0) to stamp the bundle version.
set -euo pipefail
cd "$(dirname "$0")"

UNIVERSAL=0
INSTALL=0
for arg in "$@"; do
  case "$arg" in
    --universal) UNIVERSAL=1 ;;
    --install) INSTALL=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

APP=build/NetSpeed.app
BIN="$APP/Contents/MacOS/NetSpeed"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"
if [[ -n "${VERSION:-}" ]]; then
  plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
fi

if (( UNIVERSAL )); then
  for arch in arm64 x86_64; do
    swiftc -O -swift-version 5 -target "$arch-apple-macos13.0" main.swift -o "build/NetSpeed-$arch"
  done
  lipo -create build/NetSpeed-arm64 build/NetSpeed-x86_64 -output "$BIN"
  rm build/NetSpeed-arm64 build/NetSpeed-x86_64
else
  swiftc -O -swift-version 5 main.swift -o "$BIN"
fi
codesign --force --sign - "$APP"
echo "Built $APP ($(lipo -archs "$BIN"))"

if (( INSTALL )); then
  pkill -x NetSpeed || true
  rm -rf /Applications/NetSpeed.app
  cp -R "$APP" /Applications/
  open /Applications/NetSpeed.app
  echo "Installed to /Applications and launched"
fi
