#!/usr/bin/env bash
# Captures 4 portrait screenshots from MER running on the Android emulator.
# Pre-conditions: emulator booted, APK installed, prefs pre-loaded.

ADB="/c/Users/wjl25/AppData/Local/Android/Sdk/platform-tools/adb.exe"
PKG="au.com.notiva.medical_event_recorder"
ACTIVITY="au.com.notiva.medical_event_recorder.MainActivity"
OUT="C:/dev/notiva-site/public/screenshots"

# ── helpers ──────────────────────────────────────────────────────────────────

wait_for_idle() {
  "$ADB" shell uiautomator events 2>/dev/null &
  sleep "$1"
  kill %1 2>/dev/null
}

screencap_to() {
  local name=$1
  "$ADB" exec-out screencap -p > "$OUT/$name"
  echo "Captured: $name"
}

tap_text() {
  # Dump UI, extract bounds for first element with given text, tap its centre.
  local txt=$1
  "$ADB" shell uiautomator dump /sdcard/uidump.xml 2>/dev/null
  local bounds
  bounds=$("$ADB" shell grep -o "text=\"${txt}\"[^/]*bounds=\"\[[0-9,]*\]\[[0-9,]*\]\"" /sdcard/uidump.xml 2>/dev/null | head -1 \
            | grep -o 'bounds="\[[0-9,]*\]\[[0-9,]*\]"')
  if [[ -z "$bounds" ]]; then
    echo "  Warning: could not find text '${txt}' — skipping tap"
    return 1
  fi
  # bounds="[x1,y1][x2,y2]"
  local x1 y1 x2 y2
  x1=$(echo "$bounds" | grep -oP '\[\K[0-9]+(?=,)')
  y1=$(echo "$bounds" | grep -oP ',\K[0-9]+(?=\])')
  x2=$(echo "$bounds" | grep -oP '\]\[\K[0-9]+(?=,)')
  y2=$(echo "$bounds" | grep -oP ',\K[0-9]+(?=\]\s*$)')
  local cx=$(( (x1 + x2) / 2 ))
  local cy=$(( (y1 + y2) / 2 ))
  "$ADB" shell input tap "$cx" "$cy"
  echo "  Tapped '$txt' at ($cx,$cy)"
}

tap_description() {
  # Same but matches content-desc attribute.
  local desc=$1
  "$ADB" shell uiautomator dump /sdcard/uidump.xml 2>/dev/null
  local bounds
  bounds=$("$ADB" shell grep -o "content-desc=\"${desc}\"[^/]*bounds=\"\[[0-9,]*\]\[[0-9,]*\]\"" /sdcard/uidump.xml 2>/dev/null | head -1 \
            | grep -o 'bounds="\[[0-9,]*\]\[[0-9,]*\]"')
  if [[ -z "$bounds" ]]; then
    echo "  Warning: could not find content-desc '${desc}' — skipping tap"
    return 1
  fi
  local x1 y1 x2 y2
  x1=$(echo "$bounds" | grep -oP '\[\K[0-9]+(?=,)')
  y1=$(echo "$bounds" | grep -oP ',\K[0-9]+(?=\])')
  x2=$(echo "$bounds" | grep -oP '\]\[\K[0-9]+(?=,)')
  y2=$(echo "$bounds" | grep -oP ',\K[0-9]+(?=\]\s*$)')
  local cx=$(( (x1 + x2) / 2 ))
  local cy=$(( (y1 + y2) / 2 ))
  "$ADB" shell input tap "$cx" "$cy"
  echo "  Tapped '$desc' at ($cx,$cy)"
}

press_back() { "$ADB" shell input keyevent 4; sleep 1; }

# ── main ─────────────────────────────────────────────────────────────────────

echo "=== MER screenshot capture ==="

# 1. Launch app
"$ADB" shell am start -n "$PKG/$ACTIVITY" 2>/dev/null
sleep 4

# Screenshot 1: Home screen
screencap_to "mer-1.png"

# 2. Open "Log new event" screen via "Record with details" button
tap_text "Record with details"
sleep 2

# Screenshot 2: Log new event form
screencap_to "mer-2.png"

# Go back to home
press_back

# 3. Open History via top-right popup menu
tap_description "More options"
sleep 1
tap_text "History"
sleep 2

# Screenshot 3: Event history list
screencap_to "mer-3.png"

# 4. Open export options from history screen
tap_description "Export CSV (filtered)"
sleep 2

# Screenshot 4: Export options bottom sheet
screencap_to "mer-4.png"

echo "=== Done — 4 screenshots saved to $OUT ==="
