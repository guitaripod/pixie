#!/bin/bash
# Language is switched through the simulator's global defaults: -AppleLanguages launch arguments are ignored by simctl launch.
# Capture raw App Store screenshots per locale on an iPhone 17 Pro Max simulator.
# Usage: marketing/shoot.sh <Pixie.app built for iphonesimulator> [locale ...]
# PX_SIM_UDID picks the simulator and PX_RAW_SUBDIR (e.g. "ipad") nests the captures, which is how the
# 13-inch iPad set is shot; PX_SCREENS overrides the listing's screen list. Before/after entries in the listing have no "screen" and need no capture.
set -euo pipefail
APP=${1:?path to Pixie.app}; shift
UDID=${PX_SIM_UDID:-B63090D4-6D6F-467D-B504-672EA3E95500}
ROOT=$(cd "$(dirname "$0")" && pwd)
LOCALES=${@:-$(ls "$ROOT"/listing | sed 's/\.json$//')}
lang_for() { case "$1" in en-US) echo en;; en-GB) echo en-GB;; en-AU) echo en-AU;; de-DE) echo de;; es-ES) echo es;; es-MX) echo es-MX;; fr-FR) echo fr;; it) echo it;; ja) echo ja;; ko) echo ko;; pl) echo pl;; pt-BR) echo pt-BR;; zh-Hans) echo zh-Hans;; zh-Hant) echo zh-Hant;; esac; }
locale_for() { case "$1" in en-US) echo en_US;; en-GB) echo en_GB;; en-AU) echo en_AU;; de-DE) echo de_DE;; es-ES) echo es_ES;; es-MX) echo es_MX;; fr-FR) echo fr_FR;; it) echo it_IT;; ja) echo ja_JP;; ko) echo ko_KR;; pl) echo pl_PL;; pt-BR) echo pt_BR;; zh-Hans) echo zh_CN;; zh-Hant) echo zh_TW;; esac; }
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
xcrun simctl install "$UDID" "$APP"
for locale in $LOCALES; do
  out="$ROOT/raw/$locale${PX_RAW_SUBDIR:+/$PX_RAW_SUBDIR}"; mkdir -p "$out"
  xcrun simctl spawn "$UDID" defaults write "Apple Global Domain" AppleLanguages -array "$(lang_for "$locale")"
  xcrun simctl spawn "$UDID" defaults write "Apple Global Domain" AppleLocale "$(locale_for "$locale")"
  screens=${PX_SCREENS:-$(python3 -c "import json;print(' '.join(e['screen'] for e in json.load(open('$ROOT/listing/$locale.json'))['screenshots'] if 'screen' in e))")}
  for screen in $screens; do
    xcrun simctl terminate "$UDID" com.guitaripod.Pixie 2>/dev/null || true
    SIMCTL_CHILD_PX_DEMO=$screen xcrun simctl launch "$UDID" com.guitaripod.Pixie >/dev/null
    sleep ${PX_SETTLE:-4}
    xcrun simctl io "$UDID" screenshot "$out/$screen.png" >/dev/null 2>&1
    echo "$locale/$screen.png"
  done
done
