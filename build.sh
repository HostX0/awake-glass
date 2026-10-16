#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/ModuleCache
app="build/Awake Glass.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
xcrun clang -fobjc-arc -fmodules -fmodules-cache-path=build/ModuleCache \
  -O2 -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=26.0 \
  Sources/main.m Sources/AGSession.m \
  -framework Cocoa -framework IOKit -framework QuartzCore -framework CoreGraphics \
  -o "$app/Contents/MacOS/AwakeGlass"
cp Info.plist "$app/Contents/Info.plist"
if [[ -f Assets/AppIcon.icns ]]; then cp Assets/AppIcon.icns "$app/Contents/Resources/"; fi
codesign --force --sign - "$app"
printf 'Built %s\n' "$app"
