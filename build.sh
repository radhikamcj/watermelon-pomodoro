#!/bin/bash
# Builds Watermelon.app into build/. Run: ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Watermelon.app"

swift build -c release

if [ ! -f Resources/AppIcon.icns ]; then
    mkdir -p build
    swift scripts/make_icon.swift
    iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/WatermelonPomodoro "$APP/Contents/MacOS/Watermelon"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R Resources/Art "$APP/Contents/Resources/Art"
codesign --force --sign - "$APP" >/dev/null

echo "Built $APP"
