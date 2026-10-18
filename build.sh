#!/bin/zsh
# Builds NetSpeed.app. Pass --install to copy it to /Applications and launch it.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/NetSpeed.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"
swiftc -O -swift-version 5 main.swift -o "$APP/Contents/MacOS/NetSpeed"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x NetSpeed || true
  rm -rf /Applications/NetSpeed.app
  cp -R "$APP" /Applications/
  open /Applications/NetSpeed.app
  echo "Installed to /Applications and launched"
fi
