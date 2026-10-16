#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/ModuleCache
xcrun clang -fobjc-arc -fmodules -fmodules-cache-path=build/ModuleCache \
  -O1 -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=26.0 \
  Tests/session-tests.m Sources/AGSession.m \
  -framework Cocoa -framework IOKit -framework CoreGraphics -o build/session-tests
./build/session-tests "$@"
