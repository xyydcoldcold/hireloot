#!/bin/bash
# Launches the Mac build with the demo save and captures the screen.
set -euo pipefail
APP="$1"; OUT="$2"
mkdir -p "$OUT"
"$APP/Contents/MacOS/Hireloot" -HLDemo YES -HLLang zh -HLTab today &
PID=$!
sleep 8
osascript -e 'tell application "System Events" to set frontmost of (first process whose unix id is '"$PID"') to true' || true
sleep 1
screencapture -x "$OUT/mac-zh-today.png"
kill $PID || true
"$APP/Contents/MacOS/Hireloot" -HLDemo YES -HLLang en -HLTab armory &
PID=$!
sleep 8
screencapture -x "$OUT/mac-en-armory.png"
kill $PID || true
