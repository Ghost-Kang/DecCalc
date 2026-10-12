#!/bin/sh
# Build the oracle: links the system's private Calculate.framework through
# interface stubs and a .tbd regenerated from the live shared cache.
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
BUILD="$ROOT/.build"
FW_BIN=/System/Library/PrivateFrameworks/Calculate.framework/Versions/A/Calculate
mkdir -p "$BUILD/fw/Calculate.framework" "$BUILD/module"
{
  echo '--- !tapi-tbd'; echo 'tbd-version: 4'
  echo 'targets: [ arm64e-macos, arm64-macos ]'
  echo "install-name: '$FW_BIN'"
  echo 'exports:'; echo '  - targets: [ arm64e-macos, arm64-macos ]'; echo '    symbols: ['
  dyld_info -exports "$FW_BIN" \
    | awk '/^ +0x/ && $2 !~ /^_OBJC_(CLASS|METACLASS)_\$_/ { printf "      \047%s\047,\n", $2 }' | sed '$ s/,$//'
  echo '    ]'; echo '    objc-classes: [ CalculateResult ]'; echo '...'
} > "$BUILD/fw/Calculate.framework/Calculate.tbd"
xcrun swiftc -parse-as-library -enable-library-evolution -emit-module -module-name Calculate \
  -I "$ROOT/stub/CalcC" "$ROOT/stub/Calculate.swift" \
  -emit-module-path "$BUILD/module/Calculate.swiftmodule" -o /dev/null
xcrun swiftc -O -I "$BUILD/module" -I "$ROOT/stub/CalcC" -F "$BUILD/fw" -framework Calculate \
  "$ROOT/main.swift" "$ROOT/OpTable.swift" -o "$BUILD/oracle"
echo "Built $BUILD/oracle"
