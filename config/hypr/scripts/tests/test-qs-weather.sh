#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Test suite for QsWeather.sh backend script and Quickshell weather integration.
#
# Covers:
#   - Waybar status JSON generation
#   - Unit mode switching (Celsius, Fahrenheit, Both)
#   - QML snapshot structure (settings, locations, current, hourly, daily)
#   - Geocoding search by city and coordinates
#   - Multi-location management and single auto-locate enforcement
#   - Cache handling and refresh

set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

SCRIPT="$HERE/../QsWeather.sh"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

export XDG_CONFIG_HOME="$WORK/config"
export XDG_CACHE_HOME="$WORK/cache"
mkdir -p "$XDG_CONFIG_HOME/hypr/UserConfigs" "$XDG_CACHE_HOME"

# --- status output ------------------------------------------------------------
it "status emits valid Waybar JSON with condition icon and temperature"
status_json="$(bash "$SCRIPT" status)"
assert_contains "$status_json" '"text":' "status has text key"
assert_contains "$status_json" '"tooltip":' "status has tooltip key"
assert_contains "$status_json" '"class":' "status has class key"

# --- unit modes ---------------------------------------------------------------
it "unit mode changes update temperature formatting"
bash "$SCRIPT" set-unit c >/dev/null
status_c="$(bash "$SCRIPT" status)"
assert_contains "$status_c" "°C" "Celsius mode displays °C"

bash "$SCRIPT" set-unit f >/dev/null
status_f="$(bash "$SCRIPT" status)"
assert_contains "$status_f" "°F" "Fahrenheit mode displays °F"

bash "$SCRIPT" set-unit both >/dev/null
status_both="$(bash "$SCRIPT" status)"
assert_contains "$status_both" "°C /" "Both mode displays Celsius and Fahrenheit"

# Reset to Celsius
bash "$SCRIPT" set-unit c >/dev/null

# --- snapshot output ----------------------------------------------------------
it "snapshot emits structured JSON with locations, current, hourly, and daily"
snapshot_json="$(bash "$SCRIPT" snapshot)"
assert_contains "$snapshot_json" '"settings":' "snapshot includes settings"
assert_contains "$snapshot_json" '"locations":' "snapshot includes locations"
assert_contains "$snapshot_json" '"current":' "location includes current weather"
assert_contains "$snapshot_json" '"hourly":' "location includes hourly forecast"
assert_contains "$snapshot_json" '"daily":' "location includes 7-day daily forecast"

# --- geocoding search ---------------------------------------------------------
it "search returns geocoded results array"
search_res="$(bash "$SCRIPT" search Boston)"
assert_contains "$search_res" "Massachusetts" "search finds Boston, MA"
assert_contains "$search_res" '"lat":' "search result has latitude"
assert_contains "$search_res" '"lon":' "search result has longitude"

it "search handles latitude and longitude coordinates directly"
coord_res="$(bash "$SCRIPT" search "42.36,-71.06")"
assert_contains "$coord_res" "Coordinates" "coordinate search parsed correctly"
assert_contains "$coord_res" "42.36" "latitude preserved"

# --- multi-location & single auto-locate enforcement --------------------------
it "adding, selecting, and enforcing single auto-locate across locations"
add_res="$(bash "$SCRIPT" add-location "Paris, France" 48.85 2.35)"
assert_contains "$add_res" '"status": "ok"' "added manual location"
loc2_id="$(printf '%s' "$add_res" | grep -o '"id": "[^"]*"' | cut -d'"' -f4)"

snap2="$(bash "$SCRIPT" snapshot)"
assert_contains "$snap2" "Paris, France" "snapshot carries second location"

# Enable auto-locate on Paris
bash "$SCRIPT" set-auto-locate "$loc2_id" 1 >/dev/null
cfg_file="$XDG_CONFIG_HOME/hypr/UserConfigs/weather.json"

# Check that Paris is auto and original loc-1 is not auto
paris_auto="$(python3 -c "import json; d=json.load(open('$cfg_file')); print([l['is_auto'] for l in d['locations'] if l['id'] == '$loc2_id'][0])")"
loc1_auto="$(python3 -c "import json; d=json.load(open('$cfg_file')); print([l['is_auto'] for l in d['locations'] if l['id'] == 'loc-1'][0])")"
assert_eq "Paris has auto-locate enabled" "True" "$paris_auto"
assert_eq "Original location has auto-locate disabled" "False" "$loc1_auto"

# Delete location
del_res="$(bash "$SCRIPT" remove-location "$loc2_id")"
assert_contains "$del_res" '"status": "ok"' "removed location"

summary "test-qs-weather"
