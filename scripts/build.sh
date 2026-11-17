#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="${1:-$root/build}"
staging="$(mktemp -d /private/tmp/jobquest-build.XXXXXX)"
trap 'rm -rf "$staging"' EXIT

app="$staging/求职冒险.app"
contents="$app/Contents"
architecture="$(uname -m)"
mkdir -p "$contents/MacOS" "$contents/Resources" "$staging/module-cache"

xcrun swiftc -swift-version 5 -parse-as-library -O \
    -target "$architecture-apple-macosx14.0" \
    -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
    -module-cache-path "$staging/module-cache" \
    "$root"/Sources/*.swift -o "$contents/MacOS/JobQuest"
cp -X "$root/Info.plist" "$contents/Info.plist"
cp -X "$root/Assets/camp.png" "$root/Assets/JobQuest.icns" "$contents/Resources/"
codesign --force --sign - "$app"
codesign --verify --strict "$app"

mkdir -p "$build_dir"
installed="$build_dir/求职冒险.app"
ditto --norsrc "$app" "$installed"
printf '%s\n' "$installed"
