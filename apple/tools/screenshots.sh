#!/bin/bash
# Installs the app on an iPhone simulator and screenshots each tab with the demo save.
#   bash apple/tools/screenshots.sh <path/to/Hireloot.app> <out dir>
set -euo pipefail
APP="$1"; OUT="$2"; BID=com.hireloot.app
mkdir -p "$OUT"
DEV=$(xcrun simctl list devices available | grep -E "iPhone 1[5-9] Pro \(" | grep -v Max | head -1 | grep -oE "[0-9A-F-]{36}" || true)
[ -n "$DEV" ] || DEV=$(xcrun simctl list devices available | grep -E "iPhone" | head -1 | grep -oE "[0-9A-F-]{36}")
echo "Simulator: $(xcrun simctl list devices | grep "$DEV")"
xcrun simctl boot "$DEV" || true
xcrun simctl bootstatus "$DEV" -b
xcrun simctl status_bar "$DEV" override --time 9:41 --batteryState charged --batteryLevel 100 || true
xcrun simctl install "$DEV" "$APP"

shot() { # name, then launch args
  local name="$1"; shift
  xcrun simctl terminate "$DEV" "$BID" 2>/dev/null || true
  xcrun simctl launch "$DEV" "$BID" "$@" >/dev/null
  sleep "${WAIT:-5}"
  xcrun simctl io "$DEV" screenshot "$OUT/iphone-$name.png" >/dev/null
  echo "shot $name"
}
# First launch with no save: the sign-in screen
shot login-zh -HLLang zh
for lang in zh en; do
  for tab in today boss armory log; do
    shot "$lang-$tab" -HLDemo YES -HLLang $lang -HLTab $tab
  done
done
shot zh-picker -HLDemo YES -HLLang zh -HLTab boss -HLPicker YES
shot zh-calendar -HLDemo YES -HLLang zh -HLTab boss -HLCalendar YES
shot zh-card -HLDemo YES -HLLang zh -HLTab armory -HLView YES
shot zh-settings -HLDemo YES -HLDemoAccount YES -HLLang zh -HLSettings YES
shot en-settings -HLDemo YES -HLDemoAccount YES -HLLang en -HLSettings YES
WAIT=9 shot zh-packs -HLDemo YES -HLDemoPacks YES -HLLang zh -HLOpenPacks YES -HLAutoTear YES
