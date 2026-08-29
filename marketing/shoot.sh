#!/bin/bash
# Language is switched through the simulator's global defaults: -AppleLanguages launch arguments are ignored by simctl launch.
# Capture raw App Store screenshots per locale on an iPhone 17 Pro Max simulator.
# Usage: marketing/shoot.sh <Pixie.app built for iphonesimulator> [locale ...]
set -euo pipefail
APP=${1:?path to Pixie.app}; shift
UDID=${PX_SIM_UDID:-B63090D4-6D6F-467D-B504-672EA3E95500}
ROOT=$(cd "$(dirname "$0")" && pwd)
LOCALES=${@:-$(ls "$ROOT"/listing | sed 's/\.json$//')}
lang_for() { case "$1" in en-US) echo en;; de-DE) echo de;; es-ES) echo es;; fr-FR) echo fr;; it) echo it;; ja) echo ja;; ko) echo ko;; pt-BR) echo pt-BR;; zh-Hans) echo zh-Hans;; zh-Hant) echo zh-Hant;; esac; }
locale_for() { case "$1" in en-US) echo en_US;; de-DE) echo de_DE;; es-ES) echo es_ES;; fr-FR) echo fr_FR;; it) echo it_IT;; ja) echo ja_JP;; ko) echo ko_KR;; pt-BR) echo pt_BR;; zh-Hans) echo zh_CN;; zh-Hant) echo zh_TW;; esac; }
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
xcrun simctl install "$UDID" "$APP"
for locale in $LOCALES; do
  out="$ROOT/raw/$locale"; mkdir -p "$out"
  xcrun simctl spawn "$UDID" defaults write "Apple Global Domain" AppleLanguages -array "$(lang_for "$locale")"
  xcrun simctl spawn "$UDID" defaults write "Apple Global Domain" AppleLocale "$(locale_for "$locale")"
  for screen in $(python3 -c "import json;print(' '.join(e['screen'] for e in json.load(open('$ROOT/listing/$locale.json'))['screenshots']))"); do
    xcrun simctl terminate "$UDID" com.guitaripod.Pixie 2>/dev/null || true
    SIMCTL_CHILD_PX_DEMO=$screen xcrun simctl launch "$UDID" com.guitaripod.Pixie >/dev/null
    sleep 4
    xcrun simctl io "$UDID" screenshot "$out/$screen.png" >/dev/null 2>&1
    echo "$locale/$screen.png"
  done
done
