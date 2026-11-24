#!/bin/bash
# Raw Mac App Store screenshots: captures just the Hireloot window (no desktop, no shadow).
#   bash apple/tools/mac-store-shots.sh <path/to/Hireloot.app> <out dir>
# Writes <out>/mac-<lang>-<name>.png. store-compose.js frames them at 2880x1800.
set -euo pipefail
APP="$1"; OUT="$2"
mkdir -p "$OUT"
BIN="$APP/Contents/MacOS/Hireloot"
cat > /tmp/winid.swift <<'SW'
import CoreGraphics
import Foundation
let pid = Int(CommandLine.arguments[1])!
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in list where (w["kCGWindowOwnerPID"] as? Int) == pid && (w["kCGWindowLayer"] as? Int) == 0 {
    print(w["kCGWindowNumber"]!); exit(0)
}
exit(1)
SW
swiftc -O /tmp/winid.swift -o /tmp/winid
# keep the window clear of the Dock on the small CI screen
defaults write com.apple.dock autohide -bool true && killall Dock || true
shot() {
  local name="$1"; shift
  "$BIN" -HLDemo YES -HLWindowSize 1120x700 -ApplePersistenceIgnoreState YES "$@" &
  local PID=$!
  sleep "${WAIT:-8}"
  local WID="" i
  for i in 1 2 3 4 5 6; do WID=$(/tmp/winid $PID || true); [ -n "$WID" ] && break; sleep 3; done
  if [ -n "$WID" ]; then screencapture -x -o -l"$WID" "$OUT/mac-$name.png"; echo "shot mac-$name"
  else echo "no window for $name"; fi
  kill $PID || true; sleep 1
}
# warm-up launch: the very first launch on a fresh runner can be slow to show its window
WAIT=12 shot "warmup" -HLLang en -HLTab today; rm -f "$OUT/mac-warmup.png"
for lang in zh en; do
  shot "$lang-today"  -HLLang $lang -HLTab today
  shot "$lang-boss"   -HLLang $lang -HLTab boss
  shot "$lang-armory" -HLLang $lang -HLTab armory
  shot "$lang-card"   -HLLang $lang -HLTab armory -HLView YES
  shot "$lang-log"    -HLLang $lang -HLTab log
  WAIT=12 shot "$lang-packs" -HLDemoPacks YES -HLLang $lang -HLOpenPacks YES -HLAutoTear YES
done
