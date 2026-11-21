#!/bin/bash
# Full-resolution App Store screenshots on the largest iPhone and iPad simulators.
#   bash apple/tools/store-shots.sh <path/to/Hireloot.app> <out dir>
# Writes <out>/<device>-<lang>-<name>.png (device: iphone | ipad).
set -euo pipefail
APP="$1"; OUT="$2"; BID=com.hireloot.app
mkdir -p "$OUT"
xcrun simctl list devices available

pick() { xcrun simctl list devices available | grep -E "$1" | head -1 | grep -oE "[0-9A-F-]{36}" || true; }
run_device() { # label, device id
  local label="$1" DEV="$2"
  echo "== $label: $(xcrun simctl list devices | grep "$DEV")"
  xcrun simctl boot "$DEV" || true
  xcrun simctl bootstatus "$DEV" -b
  xcrun simctl status_bar "$DEV" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 || true
  xcrun simctl install "$DEV" "$APP"
  shot() {
    local name="$1"; shift
    xcrun simctl terminate "$DEV" "$BID" 2>/dev/null || true
    xcrun simctl launch "$DEV" "$BID" "$@" >/dev/null
    sleep "${WAIT:-6}"
    xcrun simctl io "$DEV" screenshot "$OUT/$label-$name.png" >/dev/null
    echo "shot $label-$name"
  }
  for lang in zh en; do
    shot "$lang-today"  -HLDemo YES -HLLang $lang -HLTab today
    shot "$lang-boss"   -HLDemo YES -HLLang $lang -HLTab boss
    shot "$lang-armory" -HLDemo YES -HLLang $lang -HLTab armory
    shot "$lang-card"   -HLDemo YES -HLLang $lang -HLTab armory -HLView YES
    shot "$lang-log"    -HLDemo YES -HLLang $lang -HLTab log
    WAIT=10 shot "$lang-packs" -HLDemo YES -HLDemoPacks YES -HLLang $lang -HLOpenPacks YES -HLAutoTear YES
  done
  xcrun simctl shutdown "$DEV" || true
}

PHONE=$(pick "iPhone 16 Pro Max \(")
[ -n "$PHONE" ] || PHONE=$(pick "iPhone 1[5-9] Pro Max \(")
PAD=$(pick "iPad Pro 13-inch")
[ -n "$PAD" ] || PAD=$(pick "iPad Pro \(12.9-inch\)")
run_device iphone "$PHONE"
[ -n "$PAD" ] && run_device ipad "$PAD"
