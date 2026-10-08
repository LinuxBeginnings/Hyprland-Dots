#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Guards the fixtures the multi-monitor suites read. A fixture that silently
#   loses a field makes every later suite test the wrong thing, so the shapes
#   the other suites rely on are asserted here once.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

F="$HERE/fixtures"

for f in monitors-dual monitors-triple monitors-quad-2rows monitors-twins-noserial \
         monitors-nomakemodel monitors-rotated monitors-empty monitors-nomodes \
         store-empty store-v1 store-future store-missing-default; do
  check "fixture $f is valid JSON" jq -e . "$F/$f.json"
done

check "the malformed store really is malformed" \
  bash -c "! jq -e . '$F/store-malformed.json' >/dev/null 2>&1"

assert_json_eq "$F/monitors-dual.json"           'length' 2
assert_json_eq "$F/monitors-triple.json"         'length' 3
assert_json_eq "$F/monitors-quad-2rows.json"     'length' 4
assert_json_eq "$F/monitors-empty.json"          'length' 0
assert_json_eq "$F/monitors-twins-noserial.json" '[.[] | select(.serial == "")] | length' 2
assert_json_eq "$F/monitors-twins-noserial.json" '[.[].name] | unique | length' 2
assert_json_eq "$F/monitors-rotated.json"        '[.[] | select(.transform == 1)] | length' 1
assert_json_eq "$F/monitors-nomodes.json"        '[.[] | select((.availableModes | length) == 0)] | length' 1
assert_json_eq "$F/monitors-nomakemodel.json"    '[.[] | select(.make == "" and .model == "")] | length' 1

# Every monitors fixture must carry the fields ds_normalize reads, or the
# normalizer's // defaults would hide a broken fixture.
for f in monitors-dual monitors-triple monitors-quad-2rows monitors-twins-noserial \
         monitors-nomakemodel monitors-rotated monitors-nomodes; do
  check "fixture $f has every field ds_normalize reads" \
    jq -e 'all(.[]; has("name") and has("make") and has("model") and has("serial")
            and has("width") and has("height") and has("refreshRate")
            and has("x") and has("y") and has("scale") and has("transform")
            and has("disabled") and has("availableModes"))' "$F/$f.json"
done

# availableModes must keep the trailing Hz that hyprctl really prints, because
# stripping it is ds_normalize's job and a fixture without it proves nothing.
check "available modes keep the Hz suffix hyprctl prints" \
  jq -e 'all(.[] | .availableModes[]?; test("Hz$"))' "$F/monitors-triple.json"

assert_json_eq "$F/store-empty.json"  '.version' 1
assert_json_eq "$F/store-empty.json"  '.fingerprints | length' 0
assert_json_eq "$F/store-future.json" '.version' 99
assert_json_eq "$F/store-v1.json"     '.fingerprints | length' 1
assert_json_eq "$F/store-v1.json"     '.fingerprints[].layouts | keys | sort | join(",")' 'Home,Work'
assert_json_eq "$F/store-v1.json"     '.fingerprints[].default' 'Home'
assert_json_eq "$F/store-v1.json" \
  '.fingerprints[].layouts.Work.monitors | map(select(.enabled == false)) | length' 1
assert_json_eq "$F/store-missing-default.json" '.fingerprints[].default' 'Gone'
assert_json_eq "$F/store-missing-default.json" \
  '.fingerprints[].layouts | keys | join(",")' 'Alpha'

# The fingerprint used as store-v1's key must be exactly the sorted join of the
# dual fixture's identities, or every resolution test would match nothing.
it "store-v1's key is the dual fixture's fingerprint"
expected="$(jq -r '[ .[] | (if (.make == "" and .model == "") then .name
                            else (.make + "|" + .model + "|" + .serial) end) ]
                  | sort | join(" + ")' "$F/monitors-dual.json")"
actual="$(jq -r '.fingerprints | keys | .[0]' "$F/store-v1.json")"
if [[ $expected == "$actual" ]]; then pass_msg
else fail "store-v1 key is '$actual' but the dual fixture fingerprints as '$expected'"; fi

summary "test-fixtures"
