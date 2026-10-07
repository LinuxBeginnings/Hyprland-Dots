#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests for lib_display_store.sh. Everything here runs from JSON fixtures:
#   no monitors, no hyprctl, no session. That is the point of keeping the
#   library free of session state.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"
F="$HERE/fixtures"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT
# shellcheck source=../lib_display_store.sh
source "$HERE/../lib_display_store.sh"

norm() { ds_normalize "$F/monitors-$1.json" >"$WORK/$1.norm.json"; printf '%s' "$WORK/$1.norm.json"; }

# --- identity and fingerprint ---------------------------------------------
n_dual="$(norm dual)"
assert_json_eq "$n_dual" '.[0].port'     'DP-2'
assert_json_eq "$n_dual" '.[0].identity' 'ASUSTek COMPUTER INC|VG249Q3A|S7LMBS003105'
assert_json_eq "$n_dual" '.[1].identity' 'BOE|0x0630|'
assert_json_eq "$n_dual" '.[1].modes[0]' '1920x1080@60.00'
assert_json_eq "$n_dual" '.[0].modes | length' '3'
assert_eq "fingerprint of the dual set" \
  'ASUSTek COMPUTER INC|VG249Q3A|S7LMBS003105 + BOE|0x0630|' \
  "$(ds_fingerprint "$n_dual")"

n_nmm="$(norm nomakemodel)"
assert_eq "identity falls back to the port name when make and model are empty" \
  'HDMI-A-2' "$(jq -r '.[] | select(.make == "") | .identity' "$n_nmm")"

n_twins="$(norm twins-noserial)"
assert_eq "twins share one identity" '1' \
  "$(jq -r '[.[].identity] | unique | length' "$n_twins")"
assert_eq "twins keep distinct ports" '2' \
  "$(jq -r '[.[].port] | unique | length' "$n_twins")"
assert_eq "a twin fingerprint repeats the identity, so the set size is visible" \
  'AOC|24G2| + AOC|24G2|' "$(ds_fingerprint "$n_twins")"

n_empty="$(norm empty)"
assert_eq "an empty monitor list yields an empty fingerprint" '' "$(ds_fingerprint "$n_empty")"
assert_eq "an empty monitor list counts zero" '0' "$(ds_count "$n_empty")"
assert_eq "the dual set counts two" '2' "$(ds_count "$n_dual")"

n_nomodes="$(norm nomodes)"
assert_eq "a monitor with no available modes normalizes to an empty modes array" '0' \
  "$(jq -r '.[0].modes | length' "$n_nomodes")"

n_rot="$(norm rotated)"
assert_json_eq "$n_rot" '.[] | select(.port == "DP-2") | .transform' '1'

# Normalization must be stable regardless of the order hyprctl reports.
it "the fingerprint does not depend on hyprctl's ordering"
jq -c 'reverse' "$F/monitors-triple.json" >"$WORK/rev.json"
a="$(ds_normalize "$F/monitors-triple.json" >"$WORK/a.json"; ds_fingerprint "$WORK/a.json")"
b="$(ds_normalize "$WORK/rev.json" >"$WORK/b.json"; ds_fingerprint "$WORK/b.json")"
if [[ $a == "$b" && -n $a ]]; then pass_msg; else fail "'$a' != '$b'"; fi

# The old fixtures have no make/model, so they must still normalize via the
# port-name fallback rather than crashing.
# Called directly, not through `bash -c`: these are shell functions and a
# subshell spawned by bash -c would not have them.
ds_normalize "$F/dual.json" >"$WORK/legacy.json"
assert_eq "legacy fixtures without make/model fall back to the port name" \
  'DP-2' "$(jq -r '.[0].identity' "$WORK/legacy.json")"

# --- store status, reading, writability ------------------------------------
assert_eq "a missing store"   'missing'   "$(ds_store_status "$WORK/nope.json")"
assert_eq "an empty store"    'ok'        "$(ds_store_status "$F/store-empty.json")"
assert_eq "a v1 store"        'ok'        "$(ds_store_status "$F/store-v1.json")"
assert_eq "a malformed store" 'malformed' "$(ds_store_status "$F/store-malformed.json")"
assert_eq "a future store"    'future'    "$(ds_store_status "$F/store-future.json")"

assert_eq "a malformed store reads as an empty store" '0' \
  "$(ds_store_read "$F/store-malformed.json" | jq -r '.fingerprints | length')"
assert_eq "a missing store reads as an empty store" '1' \
  "$(ds_store_read "$WORK/nope.json" | jq -r '.version')"
assert_eq "a valid store reads its fingerprints" '1' \
  "$(ds_store_read "$F/store-v1.json" | jq -r '.fingerprints | length')"
assert_eq "a future store is still readable" '1' \
  "$(ds_store_read "$F/store-future.json" | jq -r '.fingerprints | length')"

it "an ok store is writable";     ds_store_writable "$F/store-empty.json" && pass_msg || fail "should be writable"
it "a missing store is writable"; ds_store_writable "$WORK/nope.json"     && pass_msg || fail "should be writable"
it "a malformed store is not writable"
ds_store_writable "$F/store-malformed.json" && fail "must refuse" || pass_msg
it "a future store is not writable"
ds_store_writable "$F/store-future.json" && fail "must refuse" || pass_msg

# --- name rules ------------------------------------------------------------
for good in 'Home' 'Work' 'Game 144.0_x-y' '-n' 'a'; do
  it "name '$good' is accepted"
  ds_name_valid "$good" && pass_msg || fail "should accept '$good'"
done
for bad in '' 'a/b' 'a"b' 'a$b' 'a;b' 'a`b' 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' 'a
b'; do
  it "name '${bad:0:12}' is rejected"
  ds_name_valid "$bad" && fail "must reject" || pass_msg
done

# --- layout validation -----------------------------------------------------
jq -c '.fingerprints[].layouts.Home' "$F/store-v1.json" >"$WORK/good.json"
it "the spec's example layout validates"
ds_validate_layout "$WORK/good.json" 2>/dev/null && pass_msg || fail "should validate"

jq -c '.fingerprints[].layouts.Work' "$F/store-v1.json" >"$WORK/work.json"
it "a layout with one monitor disabled still validates"
ds_validate_layout "$WORK/work.json" 2>/dev/null && pass_msg || fail "should validate"

reject() {  # label, jq-filter applied to the good layout
  local label=$1 filter=$2
  jq -c "$filter" "$WORK/good.json" >"$WORK/bad.json"
  it "$label"
  if ds_validate_layout "$WORK/bad.json" 2>/dev/null; then fail "must be rejected"; else pass_msg; fi
}
reject "a layout with no monitors is rejected"          '.monitors = []'
reject "a layout with every monitor disabled is rejected" '.monitors |= map(.enabled = false)'
reject "scale 0 is rejected"                            '.monitors[0].scale = 0'
reject "a negative scale is rejected"                   '.monitors[0].scale = -1.5'
reject "a non-WxH@R mode is rejected"                   '.monitors[0].mode = "preferred"'
reject "an empty mode is rejected"                      '.monitors[0].mode = ""'
reject "transform 9 is rejected"                        '.monitors[0].transform = 9'
reject "a negative transform is rejected"               '.monitors[0].transform = -1'
reject "an unknown waybar mode is rejected"             '.waybar.mode = "sometimes"'
reject "a monitor without an identity is rejected"      'del(.monitors[0].identity)'
reject "an empty identity is rejected"                  '.monitors[0].identity = ""'
reject "monitors as an object is rejected"              '.monitors = {}'

it "a non-object layout is rejected"
printf '[]\n' >"$WORK/notobj.json"
if ds_validate_layout "$WORK/notobj.json" 2>/dev/null; then fail "must be rejected"; else pass_msg; fi

it "validation says why on stderr"
jq -c '.monitors = []' "$WORK/good.json" >"$WORK/bad.json"
reason="$(ds_validate_layout "$WORK/bad.json" 2>&1 >/dev/null || true)"
case $reason in *empty*) pass_msg ;; *) fail "unhelpful reason: '$reason'" ;; esac


# --- geometry: logical size ------------------------------------------------
assert_eq "scale 1 keeps the panel size"       '1920 1080' "$(ds_logical_size 1920x1080@60.00 1 0)"
assert_eq "scale 1.5 shrinks the logical size" '1280 720'  "$(ds_logical_size 1920x1080@60.00 1.5 0)"
assert_eq "scale 1.25 on 2560x1440"            '2048 1152' "$(ds_logical_size 2560x1440@59.95 1.25 0)"
assert_eq "transform 1 swaps width and height" '1080 1920' "$(ds_logical_size 1920x1080@60.00 1 1)"
assert_eq "transform 3 swaps too"              '1080 1920' "$(ds_logical_size 1920x1080@60.00 1 3)"
assert_eq "transform 5 swaps too"              '1080 1920' "$(ds_logical_size 1920x1080@60.00 1 5)"
assert_eq "transform 2 does not swap"          '1920 1080' "$(ds_logical_size 1920x1080@60.00 1 2)"
assert_eq "transform 4 does not swap"          '1920 1080' "$(ds_logical_size 1920x1080@60.00 1 4)"
it "scale 0 is refused rather than dividing by zero"
if ds_logical_size 1920x1080@60.00 0 0 >/dev/null 2>&1; then fail "must refuse"; else pass_msg; fi

# --- geometry: grid -> coordinates -----------------------------------------
# NOTE: ds_apply_grid reads its argument twice, so never hand it /dev/stdin.
cat >"$WORK/g1.json" <<'EOS'
{"monitors":[
 {"identity":"A","port":"DP-1","enabled":true,"mode":"1920x1080@60.00","scale":1.5,"transform":0,"grid":{"row":1,"order":1,"valign":"bottom"}},
 {"identity":"B","port":"DP-2","enabled":true,"mode":"1920x1080@119.88","scale":1,"transform":0,"grid":{"row":1,"order":2,"valign":"bottom"}}
],"primary":"B","waybar":{"mode":"all","outputs":[]}}
EOS
ds_apply_grid "$WORK/g1.json" >"$WORK/g1.out.json"
assert_json_eq "$WORK/g1.out.json" '.monitors[0].x' '0'
assert_json_eq "$WORK/g1.out.json" '.monitors[1].x' '1280'
assert_json_eq "$WORK/g1.out.json" '.monitors[0].y' '360'
assert_json_eq "$WORK/g1.out.json" '.monitors[1].y' '0'

jq -c '.monitors[0].grid.valign = "top"' "$WORK/g1.json" >"$WORK/g1top.in.json"
ds_apply_grid "$WORK/g1top.in.json" >"$WORK/g1top.json"
assert_json_eq "$WORK/g1top.json" '.monitors[0].y' '0'
jq -c '.monitors[0].grid.valign = "center"' "$WORK/g1.json" >"$WORK/g1ctr.in.json"
ds_apply_grid "$WORK/g1ctr.in.json" >"$WORK/g1ctr.json"
assert_json_eq "$WORK/g1ctr.json" '.monitors[0].y' '180'

cat >"$WORK/g2.json" <<'EOS'
{"monitors":[
 {"identity":"A","port":"DP-1","enabled":true,"mode":"1920x1080@60.00","scale":1,"transform":0,"grid":{"row":1,"order":1,"valign":"top"}},
 {"identity":"B","port":"DP-2","enabled":true,"mode":"1920x1080@60.00","scale":1,"transform":0,"grid":{"row":1,"order":2,"valign":"top"}},
 {"identity":"C","port":"DP-3","enabled":true,"mode":"1920x1080@60.00","scale":1,"transform":0,"grid":{"row":2,"order":1,"valign":"top"}},
 {"identity":"D","port":"DP-4","enabled":true,"mode":"1920x1080@60.00","scale":1,"transform":0,"grid":{"row":2,"order":2,"valign":"top"}}
],"primary":"A","waybar":{"mode":"all","outputs":[]}}
EOS
ds_apply_grid "$WORK/g2.json" >"$WORK/g2.out.json"
assert_json_eq "$WORK/g2.out.json" '[.monitors[].x] | join(",")' '0,1920,0,1920'
assert_json_eq "$WORK/g2.out.json" '[.monitors[].y] | join(",")' '0,0,1080,1080'

it "order within a row is honoured, not array order"
jq -c '.monitors[0].grid.order = 2 | .monitors[1].grid.order = 1' "$WORK/g2.json" >"$WORK/g2sw.in.json"
ds_apply_grid "$WORK/g2sw.in.json" >"$WORK/g2sw.json"
if [[ "$(jq -r '[.monitors[0].x, .monitors[1].x] | join(",")' "$WORK/g2sw.json")" == "1920,0" ]]
then pass_msg; else fail "swapping order must swap x"; fi

# A LANDSCAPE panel rotated 90 degrees: mode stays the panel's own
# 1920x1080, and the transform makes it occupy 1080 wide by 1920 tall.
cat >"$WORK/g3.json" <<'EOS'
{"monitors":[
 {"identity":"A","port":"DP-1","enabled":true,"mode":"1920x1080@60.00","scale":1,"transform":0,"grid":{"row":1,"order":1,"valign":"top"}},
 {"identity":"B","port":"DP-2","enabled":true,"mode":"1920x1080@60.00","scale":1,"transform":1,"grid":{"row":1,"order":2,"valign":"top"}},
 {"identity":"C","port":"DP-3","enabled":true,"mode":"1920x1080@60.00","scale":1,"transform":0,"grid":{"row":2,"order":1,"valign":"top"}}
],"primary":"A","waybar":{"mode":"all","outputs":[]}}
EOS
ds_apply_grid "$WORK/g3.json" >"$WORK/g3.out.json"
assert_json_eq "$WORK/g3.out.json" '.monitors[1].x' '1920'
assert_json_eq "$WORK/g3.out.json" '.monitors[2].y' '1920'

# Review Focus 4: fractional logical widths must not accumulate into an overlap.
cat >"$WORK/g4.json" <<'EOS'
{"monitors":[
 {"identity":"A","port":"DP-1","enabled":true,"mode":"1920x1080@60.00","scale":1.1,"transform":0,"grid":{"row":1,"order":1,"valign":"top"}},
 {"identity":"B","port":"DP-2","enabled":true,"mode":"1920x1080@60.00","scale":1.1,"transform":0,"grid":{"row":1,"order":2,"valign":"top"}},
 {"identity":"C","port":"DP-3","enabled":true,"mode":"1920x1080@60.00","scale":1.1,"transform":0,"grid":{"row":1,"order":3,"valign":"top"}}
],"primary":"A","waybar":{"mode":"all","outputs":[]}}
EOS
ds_apply_grid "$WORK/g4.json" >"$WORK/g4.out.json"
assert_json_eq "$WORK/g4.out.json" '[.monitors[].x] | join(",")' '0,1745,3491'
assert_eq "three fractional widths do not overlap" 'ok' \
  "$(jq -r 'if (.monitors[2].x - .monitors[1].x) >= 1745 then "ok" else "overlap" end' "$WORK/g4.out.json")"

it "a disabled monitor takes no space in its row"
jq -c '.monitors[0].enabled = false' "$WORK/g2.json" >"$WORK/g5.in.json"
ds_apply_grid "$WORK/g5.in.json" >"$WORK/g5.json"
if [[ "$(jq -r '.monitors[1].x' "$WORK/g5.json")" == "0" ]]; then pass_msg
else fail "x was $(jq -r '.monitors[1].x' "$WORK/g5.json"), expected 0"; fi

it "a monitor with no grid defaults to row 1 in array order"
jq -c '[.monitors[] | del(.grid)] as $m | {monitors:$m, primary:"A", waybar:{mode:"all",outputs:[]}}' \
  "$WORK/g2.json" >"$WORK/g6.in.json"
ds_apply_grid "$WORK/g6.in.json" >"$WORK/g6.json"
if [[ "$(jq -r '[.monitors[].x] | join(",")' "$WORK/g6.json")" == "0,1920,3840,5760" ]]
then pass_msg; else fail "got $(jq -r '[.monitors[].x] | join(",")' "$WORK/g6.json")"; fi

it "a non-contiguous row number still stacks in ascending order"
jq -c '.monitors[2].grid.row = 7 | .monitors[3].grid.row = 7' "$WORK/g2.json" >"$WORK/g7.in.json"
ds_apply_grid "$WORK/g7.in.json" >"$WORK/g7.json"
if [[ "$(jq -r '[.monitors[].y] | join(",")' "$WORK/g7.json")" == "0,0,1080,1080" ]]
then pass_msg; else fail "got $(jq -r '[.monitors[].y] | join(",")' "$WORK/g7.json")"; fi

it "the grid result still validates"
ds_validate_layout "$WORK/g3.out.json" 2>/dev/null && pass_msg || fail "should validate"


# --- generation ------------------------------------------------------------
n_triple="$(norm triple)"
ds_generate "$n_triple" "$F/store-empty.json" >"$WORK/gen-triple.json"
assert_json_eq "$WORK/gen-triple.json" '.monitors[] | select(.port == "DP-1") | .mode' '2560x1440@59.95'
assert_json_eq "$WORK/gen-triple.json" '.monitors[] | select(.port == "HDMI-A-1") | .mode' '1920x1080@144.00'
assert_json_eq "$WORK/gen-triple.json" '[.monitors[].port] | join(",")' 'DP-1,DP-3,HDMI-A-1'
assert_json_eq "$WORK/gen-triple.json" '[.monitors[].x] | join(",")' '0,2560,4480'
assert_json_eq "$WORK/gen-triple.json" '[.monitors[].enabled] | unique | join(",")' 'true'
assert_json_eq "$WORK/gen-triple.json" '.waybar.mode' 'all'
assert_json_eq "$WORK/gen-triple.json" '.primary' 'Dell|U2720Q|ABC123'
it "a generated layout validates"
ds_validate_layout "$WORK/gen-triple.json" 2>/dev/null && pass_msg || fail "should validate"

# Review Focus 1: no availableModes -> fall back to the current mode, never "@".
n_nm="$(norm nomodes)"
ds_generate "$n_nm" "$F/store-empty.json" >"$WORK/gen-nm.json"
assert_json_eq "$WORK/gen-nm.json" '.monitors[0].mode' '1920x1080@59.94'
it "a generated layout with no available modes still validates"
ds_validate_layout "$WORK/gen-nm.json" 2>/dev/null && pass_msg || fail "should validate"

# --- inheritance -----------------------------------------------------------
assert_eq "an inherited scale is found"   '1.5' "$(ds_inherit 'BOE|0x0630|' "$F/store-v1.json" scale)"
assert_eq "an inherited transform is found" '0' "$(ds_inherit 'BOE|0x0630|' "$F/store-v1.json" transform)"
assert_eq "inheritance misses cleanly for an unknown identity" '' \
  "$(ds_inherit 'Nobody|Nothing|' "$F/store-v1.json" scale)"

it "generation reuses a known monitor's stored scale"
jq -c '[ .[] | select(.identity | startswith("BOE")) ]' "$n_dual" >"$WORK/norm-boe-only.json"
ds_generate "$WORK/norm-boe-only.json" "$F/store-v1.json" >"$WORK/gen-inherit.json"
if [[ "$(jq -r '.monitors[0].scale' "$WORK/gen-inherit.json")" == "1.5" ]]; then pass_msg
else fail "scale was $(jq -r '.monitors[0].scale' "$WORK/gen-inherit.json"), expected the inherited 1.5"; fi
assert_json_eq "$WORK/gen-inherit.json" '.monitors[0].x' '0'

it "inheritance search order prefers the larger monitor set, deterministically"
jq -n --slurpfile v1 "$F/store-v1.json" '
  ($v1[0].fingerprints | to_entries[0]) as $big
  | { version:1, fingerprints: {
        ($big.key): $big.value,
        "BOE|0x0630|": { label:"solo", default:"Only", layouts: { Only: {
            monitors:[{identity:"BOE|0x0630|",port:"eDP-1",enabled:true,
                       mode:"1920x1080@60.00",scale:2,transform:0,x:0,y:0,
                       grid:{row:1,order:1,valign:"top"}}],
            primary:"BOE|0x0630|", waybar:{mode:"all",outputs:[]} } } } } }' >"$WORK/store-two.json"
got="$(ds_inherit 'BOE|0x0630|' "$WORK/store-two.json" scale)"
if [[ $got == "1.5" ]]; then pass_msg
else fail "expected 1.5 from the two-monitor fingerprint, got '$got'"; fi

# --- port assignment -------------------------------------------------------
jq -c '.fingerprints[].layouts.Home' "$F/store-v1.json" >"$WORK/home.json"
it "identity wins over the stored port when a monitor moves"
jq -c '[ .[] | if (.identity | startswith("ASUSTek")) then .port = "HDMI-A-1" else . end ] | sort_by(.port)' \
  "$n_dual" >"$WORK/norm-moved.json"
ds_assign_ports "$WORK/home.json" "$WORK/norm-moved.json" >"$WORK/home-moved.json"
if [[ "$(jq -r '.monitors[] | select(.identity | startswith("ASUSTek")) | .port' "$WORK/home-moved.json")" == "HDMI-A-1" ]]
then pass_msg; else fail "the port was not re-assigned"; fi

n_tw="$(norm twins-noserial)"
cat >"$WORK/twins-layout.json" <<'EOS'
{"monitors":[
 {"identity":"AOC|24G2|","port":"DP-1","enabled":true,"mode":"1920x1080@60.00","scale":1,"transform":0,"x":0,"y":0,"grid":{"row":1,"order":1,"valign":"top"}},
 {"identity":"AOC|24G2|","port":"DP-2","enabled":true,"mode":"1920x1080@60.00","scale":1,"transform":0,"x":1920,"y":0,"grid":{"row":1,"order":2,"valign":"top"}}
],"primary":"AOC|24G2|","waybar":{"mode":"all","outputs":[]}}
EOS
ds_assign_ports "$WORK/twins-layout.json" "$n_tw" >"$WORK/twins-out.json"
assert_json_eq "$WORK/twins-out.json" '[.monitors[].port] | join(",")' 'DP-1,DP-2'
assert_json_eq "$WORK/twins-out.json" '.monitors | length' '2'

it "twins whose ports both moved are assigned deterministically, not dropped"
jq -c '[ .[] | if .port == "DP-1" then .port = "DP-5" else .port = "DP-6" end ] | sort_by(.port)' \
  "$n_tw" >"$WORK/twins-moved.json"
ds_assign_ports "$WORK/twins-layout.json" "$WORK/twins-moved.json" >"$WORK/twins-moved-out.json"
if [[ "$(jq -r '[.monitors[].port] | join(",")' "$WORK/twins-moved-out.json")" == "DP-5,DP-6" ]]
then pass_msg; else fail "got $(jq -r '[.monitors[].port] | join(",")' "$WORK/twins-moved-out.json")"; fi

it "a monitor whose identity is absent is dropped"
jq -c '[ .[] | select(.identity | startswith("ASUSTek") | not) ]' "$n_dual" >"$WORK/norm-boe.json"
ds_assign_ports "$WORK/home.json" "$WORK/norm-boe.json" >"$WORK/home-dropped.json"
if [[ "$(jq -r '.monitors | length' "$WORK/home-dropped.json")" == "1" ]]; then pass_msg
else fail "expected 1 monitor, got $(jq -r '.monitors | length' "$WORK/home-dropped.json")"; fi

# --- layout names and resolution -------------------------------------------
assert_eq "layout names of the dual set" 'Home
Work' "$(ds_layout_names "$n_dual" "$F/store-v1.json")"
assert_eq "layout names of an unknown set" '' "$(ds_layout_names "$n_triple" "$F/store-v1.json")"

ds_resolve "$n_dual" "$F/store-v1.json" >"$WORK/r-dual.json"
assert_json_eq "$WORK/r-dual.json" '.source' 'stored'
assert_json_eq "$WORK/r-dual.json" '.name'   'Home'
assert_json_eq "$WORK/r-dual.json" '.fingerprint' 'ASUSTek COMPUTER INC|VG249Q3A|S7LMBS003105 + BOE|0x0630|'
assert_json_eq "$WORK/r-dual.json" '.layout.monitors | length' '2'

ds_resolve "$n_triple" "$F/store-v1.json" >"$WORK/r-triple.json"
assert_json_eq "$WORK/r-triple.json" '.source' 'generated'
assert_json_eq "$WORK/r-triple.json" '.name'   '(auto)'

# Review Focus 2: a default naming a layout that no longer exists must not
# silently resolve to nothing.
jq -n --arg fp "$(ds_fingerprint "$n_dual")" --slurpfile v1 "$F/store-v1.json" '
  ($v1[0].fingerprints | to_entries[0].value.layouts.Home) as $l
  | { version:1, fingerprints: { ($fp): { label:"X", default:"Gone",
        layouts: { Beta: $l, Alpha: $l } } } }' >"$WORK/store-md.json"
ds_resolve "$n_dual" "$WORK/store-md.json" >"$WORK/r-md.json"
assert_json_eq "$WORK/r-md.json" '.source' 'stored'
assert_json_eq "$WORK/r-md.json" '.name'   'Alpha'

it "a fingerprint with no layouts at all falls back to a generated layout"
jq -n --arg fp "$(ds_fingerprint "$n_dual")" \
  '{version:1,fingerprints:{($fp):{label:"X",default:"",layouts:{}}}}' >"$WORK/store-nolayouts.json"
ds_resolve "$n_dual" "$WORK/store-nolayouts.json" >"$WORK/r-nl.json"
if [[ "$(jq -r '.source' "$WORK/r-nl.json")" == "generated" ]]; then pass_msg
else fail "expected a generated layout"; fi

it "resolution re-assigns ports, so a moved monitor still resolves"
ds_resolve "$WORK/norm-moved.json" "$F/store-v1.json" >"$WORK/r-moved.json" 2>/dev/null || true
if [[ "$(jq -r '.source' "$WORK/r-moved.json")" == "stored" \
   && "$(jq -r '.layout.monitors[] | select(.identity | startswith("ASUSTek")) | .port' "$WORK/r-moved.json")" == "HDMI-A-1" ]]
then pass_msg; else fail "a moved monitor broke resolution"; fi

# Review Focus 5: no monitors at all -> resolve nothing, exit 2.
it "resolve refuses an empty monitor list with exit 2"
set +e; ds_resolve "$n_empty" "$F/store-empty.json" >/dev/null 2>&1; rc=$?; set -e
if (( rc == 2 )); then pass_msg; else fail "exit was $rc, expected 2"; fi

it "a malformed store still resolves, via generation"
ds_resolve "$n_dual" "$F/store-malformed.json" >"$WORK/r-bad.json"
if [[ "$(jq -r '.source' "$WORK/r-bad.json")" == "generated" ]]; then pass_msg
else fail "a malformed store must not break resolution"; fi


# --- capture ---------------------------------------------------------------
ds_capture "$n_dual" >"$WORK/cap.json"
assert_json_eq "$WORK/cap.json" '.monitors[] | select(.port == "DP-2") | .mode' '1920x1080@119.88'
assert_json_eq "$WORK/cap.json" '.monitors[] | select(.port == "eDP-1") | .mode' '1920x1080@60.03'
assert_json_eq "$WORK/cap.json" '.monitors[] | select(.port == "eDP-1") | .scale' '1.5'
assert_json_eq "$WORK/cap.json" '.monitors[] | select(.port == "eDP-1") | .x' '0'
assert_json_eq "$WORK/cap.json" '.monitors[] | select(.port == "DP-2") | .x' '1280'
assert_json_eq "$WORK/cap.json" '.primary' 'ASUSTek COMPUTER INC|VG249Q3A|S7LMBS003105'
assert_json_eq "$WORK/cap.json" '[.monitors[].grid.row] | unique | join(",")' '1'
assert_json_eq "$WORK/cap.json" '.waybar.mode' 'all'
it "a capture validates"
ds_validate_layout "$WORK/cap.json" 2>/dev/null && pass_msg || fail "should validate"

it "capture records a disabled monitor as disabled"
jq -c '[ .[] | if (.identity | startswith("ASUSTek")) then .disabled = true else . end ]' \
  "$n_dual" >"$WORK/norm-dp-off.json"
ds_capture "$WORK/norm-dp-off.json" >"$WORK/cap-off.json"
if [[ "$(jq -r '.monitors[] | select(.identity | startswith("ASUSTek")) | .enabled' "$WORK/cap-off.json")" == "false" \
   && "$(jq -r '.monitors[] | select(.identity | startswith("BOE")) | .enabled' "$WORK/cap-off.json")" == "true" ]]
then pass_msg; else fail "enabled flags are wrong"; fi
it "a capture with one monitor off still validates"
ds_validate_layout "$WORK/cap-off.json" 2>/dev/null && pass_msg || fail "should validate"

it "capture recovers two rows from the y coordinates"
jq -c '[ .[] | if .port == "eDP-1" then (.x = 0 | .y = 1080) else . end ]' "$n_dual" >"$WORK/norm-stack.json"
ds_capture "$WORK/norm-stack.json" >"$WORK/cap-stack.json"
if [[ "$(jq -r '[.monitors[].grid.row] | unique | sort | join(",")' "$WORK/cap-stack.json")" == "1,2" ]]
then pass_msg; else fail "rows were $(jq -r '[.monitors[].grid.row] | join(",")' "$WORK/cap-stack.json")"; fi

it "capture orders a row left to right"
ds_capture "$n_triple" >"$WORK/cap-triple.json"
if [[ "$(jq -r '[.monitors[] | select(.grid.row == 1) | .grid.order] | join(",")' "$WORK/cap-triple.json")" == "1,2,3" ]]
then pass_msg; else fail "orders were $(jq -r '[.monitors[].grid.order] | join(",")' "$WORK/cap-triple.json")"; fi

it "capture of a rotated monitor keeps its transform"
ds_capture "$(norm rotated)" >"$WORK/cap-rot.json"
if [[ "$(jq -r '.monitors[] | select(.port == "DP-2") | .transform' "$WORK/cap-rot.json")" == "1" ]]
then pass_msg; else fail "transform was lost"; fi

# --- writes ----------------------------------------------------------------
cp "$F/store-empty.json" "$WORK/store.json"
FP="$(ds_fingerprint "$n_dual")"
it "set writes a layout"
ds_store_set "$WORK/store.json" "$FP" 'Home' "$WORK/cap.json" && pass_msg || fail "write failed"
assert_eq "the first layout written becomes the default" 'Home' \
  "$(jq -r --arg fp "$FP" '.fingerprints[$fp].default' "$WORK/store.json")"
assert_eq "the layout is retrievable" '2' \
  "$(jq -r --arg fp "$FP" '.fingerprints[$fp].layouts.Home.monitors | length' "$WORK/store.json")"
assert_eq "the store is still valid JSON after a write" 'ok' "$(ds_store_status "$WORK/store.json")"

it "set writes a second layout without moving the default"
ds_store_set "$WORK/store.json" "$FP" 'Work' "$WORK/cap-off.json" && pass_msg || fail "write failed"
assert_eq "the default is unchanged by a second write" 'Home' \
  "$(jq -r --arg fp "$FP" '.fingerprints[$fp].default' "$WORK/store.json")"
assert_eq "both layouts are present" 'Home,Work' \
  "$(jq -r --arg fp "$FP" '.fingerprints[$fp].layouts | keys | sort | join(",")' "$WORK/store.json")"

it "a saved layout round-trips through resolution"
ds_resolve "$n_dual" "$WORK/store.json" >"$WORK/r-rt.json"
if [[ "$(jq -r '.source' "$WORK/r-rt.json")" == "stored" && "$(jq -r '.name' "$WORK/r-rt.json")" == "Home" ]]
then pass_msg; else fail "round trip gave $(jq -rc '{source,name}' "$WORK/r-rt.json")"; fi

it "default can be moved"
ds_store_default "$WORK/store.json" "$FP" 'Work' && pass_msg || fail "could not move the default"
assert_eq "the default moved" 'Work' \
  "$(jq -r --arg fp "$FP" '.fingerprints[$fp].default' "$WORK/store.json")"
it "the default cannot be set to a layout that does not exist"
if ds_store_default "$WORK/store.json" "$FP" 'Nope' 2>/dev/null; then fail "must refuse"; else pass_msg; fi
assert_eq "a refused default change left the store alone" 'Work' \
  "$(jq -r --arg fp "$FP" '.fingerprints[$fp].default' "$WORK/store.json")"

it "label can be set"
ds_store_label "$WORK/store.json" "$FP" 'Nha' && pass_msg || fail "could not set the label"
assert_eq "the label was stored" 'Nha' \
  "$(jq -r --arg fp "$FP" '.fingerprints[$fp].label' "$WORK/store.json")"

it "delete removes a layout and re-points the default"
ds_store_delete "$WORK/store.json" "$FP" 'Work' && pass_msg || fail "delete failed"
assert_eq "deleting the default re-points it" 'Home' \
  "$(jq -r --arg fp "$FP" '.fingerprints[$fp].default' "$WORK/store.json")"
it "deleting the last layout removes the fingerprint"
ds_store_delete "$WORK/store.json" "$FP" 'Home' && pass_msg || fail "delete failed"
assert_eq "the fingerprint is gone" '0' "$(jq -r '.fingerprints | length' "$WORK/store.json")"

# --- writes are refused where they would destroy data ----------------------
cp "$F/store-malformed.json" "$WORK/bad-store.json"
before="$(cat "$WORK/bad-store.json")"
it "set refuses a malformed store"
if ds_store_set "$WORK/bad-store.json" "X" "Y" "$WORK/cap.json" 2>/dev/null; then fail "must refuse"; else pass_msg; fi
assert_eq "the malformed store was left byte-identical" "$before" "$(cat "$WORK/bad-store.json")"

cp "$F/store-future.json" "$WORK/future-store.json"
before_f="$(cat "$WORK/future-store.json")"
it "set refuses a store from a newer version"
if ds_store_set "$WORK/future-store.json" "X" "Y" "$WORK/cap.json" 2>/dev/null; then fail "must refuse"; else pass_msg; fi
assert_eq "the future store was left byte-identical" "$before_f" "$(cat "$WORK/future-store.json")"
it "delete also refuses a malformed store"
if ds_store_delete "$WORK/bad-store.json" "X" "Y" 2>/dev/null; then fail "must refuse"; else pass_msg; fi
it "label also refuses a malformed store"
if ds_store_label "$WORK/bad-store.json" "X" "Y" 2>/dev/null; then fail "must refuse"; else pass_msg; fi

it "set refuses to write an invalid layout"
jq -c '.monitors = []' "$WORK/cap.json" >"$WORK/cap-bad.json"
cp "$F/store-empty.json" "$WORK/store2.json"
if ds_store_set "$WORK/store2.json" "$FP" 'Bad' "$WORK/cap-bad.json" 2>/dev/null; then fail "must refuse"; else pass_msg; fi
assert_eq "the store stayed empty" '0' "$(jq -r '.fingerprints | length' "$WORK/store2.json")"

# --- backup ----------------------------------------------------------------
cp "$F/store-v1.json" "$WORK/tobackup.json"
bak="$(ds_store_backup "$WORK/tobackup.json")"
it "the backup exists";      [[ -f $bak ]] && pass_msg || fail "no backup at '$bak'"
it "the backup is identical"; cmp -s "$WORK/tobackup.json" "$bak" && pass_msg || fail "backup differs"

it "writes leave no temp files behind"
n="$(find "$WORK" -maxdepth 1 -name '.display-layouts.*' | wc -l | tr -d ' ')"
if [[ $n == 0 ]]; then pass_msg; else fail "$n temp files left"; fi


# --- review findings I9, I10 -----------------------------------------------
# A disabled monitor is reported by Hyprland with width/height/refreshRate all
# zero while its availableModes stay populated. Capturing "0x0@0" puts a mode
# Hyprland cannot match into the store, and switching that monitor back on in
# the table then lays it out with a logical width of zero.
n_off="$(norm dual-dp2-off)"
ds_capture "$n_off" >"$WORK/cap-off2.json"
it "capture of a disabled monitor uses one of its real modes, not 0x0@0"
m="$(jq -r '.monitors[] | select(.port == "DP-2") | .mode' "$WORK/cap-off2.json")"
if [[ $m == "1920x1080@119.88" ]]; then pass_msg; else fail "mode is '$m'"; fi

it "switching that monitor back on lays it out with a real width"
jq -c '.monitors |= map(.enabled = true)' "$WORK/cap-off2.json" >"$WORK/cap-on.in.json"
ds_apply_grid "$WORK/cap-on.in.json" >"$WORK/cap-on.json"
xs="$(jq -r '[.monitors[].x] | join(",")' "$WORK/cap-on.json")"
if [[ $xs != "0,0" ]]; then pass_msg; else fail "both monitors landed at x=0 ($xs)"; fi

it "a layout with a 0x0 mode is rejected by validation"
jq -c '.monitors[0].mode = "0x0@0"' "$WORK/good.json" >"$WORK/bad-zero.json"
if ds_validate_layout "$WORK/bad-zero.json" 2>/dev/null; then fail "must be rejected"; else pass_msg; fi

reject "a null x is rejected"            '.monitors[0].x = null'
reject "a non-numeric x is rejected"     '.monitors[0].x = "left"'
reject "a non-numeric y is rejected"     '.monitors[0].y = "top"'
reject "a fractional refresh with two dots is rejected" '.monitors[0].mode = "1920x1080@1.2.3"'
reject "a quote in x is rejected"        '.monitors[0].x = "0\" }) os.execute(\"x\") hl.monitor({"'

it "an absent x still validates and defaults to zero"
jq -c 'del(.monitors[0].x)' "$WORK/good.json" >"$WORK/noax.json"
ds_validate_layout "$WORK/noax.json" 2>/dev/null && pass_msg || fail "an absent x is fine; grid fills it in"

it "the backup can be made to fail, and says so"
cp "$F/store-v1.json" "$WORK/bk.json"
if DS_CP=/bin/false ds_store_backup "$WORK/bk.json" >/dev/null 2>&1; then
  fail "a failed copy must not report success"
else pass_msg; fi


# --- nwg-displays bridge (ds_from_nwg_conf) --------------------------------
# nwg writes a monitors.conf but the Lua fork never reads it; the bridge parses
# that file and turns it into one of our layouts, mapping desc:<description>
# back to the real device. These checks run on a hand-made nwg file.
cat >"$WORK/nwg-dual.conf" <<'EOS'
# Generated by nwg-displays on 2026-01-01 at 00:00:00. Do not edit manually.
monitor=desc:BOE 0x0630,1920x1080@60.03,0x0,1.25
monitor=desc:ASUSTek COMPUTER INC VG249Q3A S7LMBS003105,1920x1080@119.88,1536x0,1.0
EOS
ds_from_nwg_conf "$WORK/nwg-dual.conf" "$n_dual" >"$WORK/nwg-layout.json"
assert_json_eq "$WORK/nwg-layout.json" '.monitors | length' '2'
assert_json_eq "$WORK/nwg-layout.json" '.monitors[] | select(.identity|startswith("BOE")) | .port' 'eDP-1'
assert_json_eq "$WORK/nwg-layout.json" '.monitors[] | select(.identity|startswith("BOE")) | .scale' '1.25'
assert_json_eq "$WORK/nwg-layout.json" '.monitors[] | select(.identity|startswith("BOE")) | .x' '0'
assert_json_eq "$WORK/nwg-layout.json" '.monitors[] | select(.identity|startswith("ASUS")) | .port' 'DP-2'
assert_json_eq "$WORK/nwg-layout.json" '.monitors[] | select(.identity|startswith("ASUS")) | .scale' '1'
assert_json_eq "$WORK/nwg-layout.json" '.monitors[] | select(.identity|startswith("ASUS")) | .x' '1536'
assert_json_eq "$WORK/nwg-layout.json" '[.monitors[].enabled] | unique | join(",")' 'true'
it "the bridged layout validates"
ds_validate_layout "$WORK/nwg-layout.json" 2>/dev/null && pass_msg || fail "should validate"

it "a disable line maps to enabled:false"
cat >"$WORK/nwg-off.conf" <<'EOS'
monitor=desc:BOE 0x0630,1920x1080@60.03,0x0,1.0
monitor=desc:ASUSTek COMPUTER INC VG249Q3A S7LMBS003105,1920x1080@119.88,1920x0,1.0
monitor=desc:ASUSTek COMPUTER INC VG249Q3A S7LMBS003105,disable
EOS
ds_from_nwg_conf "$WORK/nwg-off.conf" "$n_dual" >"$WORK/nwg-off.json"
if [[ "$(jq -r '.monitors[]|select(.identity|startswith("ASUS"))|.enabled' "$WORK/nwg-off.json")" == "false" ]]; then pass_msg
else fail "disable line not honoured"; fi

it "a transform line is applied"
cat >"$WORK/nwg-rot.conf" <<'EOS'
monitor=desc:BOE 0x0630,1920x1080@60.03,0x0,1.0
monitor=desc:BOE 0x0630,transform,1
EOS
ds_from_nwg_conf "$WORK/nwg-rot.conf" "$n_dual" >"$WORK/nwg-rot.json"
if [[ "$(jq -r '.monitors[]|select(.identity|startswith("BOE"))|.transform' "$WORK/nwg-rot.json")" == "1" ]]; then pass_msg
else fail "transform not applied"; fi

it "## in a description is unescaped to #"
cat >"$WORK/nwg-hash.conf" <<'EOS'
monitor=desc:BOE 0x0630,1920x1080@60.03,0x0,1.0
EOS
# normalized monitor whose description contains a '#'
jq -c '[ .[] | if (.identity|startswith("BOE")) then .description="BO#E" else . end ]' "$n_dual" >"$WORK/n-hash.json"
printf 'monitor=desc:BO##E,1920x1080@60.03,0x0,1.0\n' >"$WORK/nwg-hash.conf"
ds_from_nwg_conf "$WORK/nwg-hash.conf" "$WORK/n-hash.json" >"$WORK/nwg-hash.json"
if [[ "$(jq -r '.monitors|length' "$WORK/nwg-hash.json")" == "1" ]]; then pass_msg
else fail "## was not unescaped to match the description"; fi

it "the port-name form (not desc) also maps"
printf 'monitor=eDP-1,1920x1080@60.03,0x0,1.0\n' >"$WORK/nwg-port.conf"
ds_from_nwg_conf "$WORK/nwg-port.conf" "$n_dual" >"$WORK/nwg-port.json"
if [[ "$(jq -r '.monitors[0].identity' "$WORK/nwg-port.json")" == "BOE|0x0630|" ]]; then pass_msg
else fail "port-name form did not map"; fi

it "an empty nwg file yields no usable layout (exit non-zero)"
printf '# only a comment\n' >"$WORK/nwg-empty.conf"
if ds_from_nwg_conf "$WORK/nwg-empty.conf" "$n_dual" >/dev/null 2>&1; then fail "should refuse empty"; else pass_msg; fi


# --- the nwg parser's field shapes -----------------------------------------
# A `desc:` name IS a monitor description, and descriptions contain commas
# ("Dell Inc., DELL U2412M"). Treating field 1 as the name would shift every
# following field by one and silently drop the monitor from the import.
it "a comma inside a description does not misalign the fields"
printf 'monitor=desc:ACME, Inc. X27,1920x1080@60.00,0x0,1.0\n' >"$WORK/nwg-comma.conf"
jq -c '[ .[] | if (.identity|startswith("ASUS")) then .description = "ACME, Inc. X27" else . end ]' \
  "$n_dual" >"$WORK/n-comma.norm.json"
ds_from_nwg_conf "$WORK/nwg-comma.conf" "$WORK/n-comma.norm.json" >"$WORK/n-comma.layout.json"
assert_json_eq "$WORK/n-comma.layout.json" '.monitors | length' '1'
assert_json_eq "$WORK/n-comma.layout.json" '.monitors[0].mode' '1920x1080@60.00'
assert_json_eq "$WORK/n-comma.layout.json" '.monitors[0].scale' '1'
assert_json_eq "$WORK/n-comma.layout.json" '.monitors[0].x' '0'

it "a negative position is parsed rather than dropped"
# A monitor placed left of the origin gets a negative x, which is a legitimate
# arrangement and must not make the line unparseable.
printf 'monitor=DP-2,1920x1080@119.88,-1920x0,1.0\n' >"$WORK/nwg-neg.conf"
ds_from_nwg_conf "$WORK/nwg-neg.conf" "$n_dual" >"$WORK/nwg-neg.layout.json"
assert_json_eq "$WORK/nwg-neg.layout.json" '.monitors[0].x' '-1920'

it "extras a layout cannot express are refused, not silently dropped"
# A mirrored arrangement applied as a plain one would quietly un-mirror the
# user's monitors, so the import must fail and say which setting is the problem.
printf 'monitor=DP-2,1920x1080@119.88,0x0,1.0,mirror,eDP-1\n' >"$WORK/nwg-mirror.conf"
if ds_from_nwg_conf "$WORK/nwg-mirror.conf" "$n_dual" \
     >"$WORK/nwg-mirror.layout.json" 2>"$WORK/nwg-mirror.err"; then
  fail "a mirrored arrangement must not import as a plain layout"
else pass_msg; fi
assert_contains "$WORK/nwg-mirror.err" 'mirror' "the reason names the setting that cannot be stored"

it "a 10-bit arrangement is refused for the same reason"
printf 'monitor=DP-2,1920x1080@119.88,0x0,1.0,bitdepth,10\n' >"$WORK/nwg-10bit.conf"
if ds_from_nwg_conf "$WORK/nwg-10bit.conf" "$n_dual" >/dev/null 2>&1; then
  fail "bitdepth must not be dropped silently"
else pass_msg; fi

it "an arrangement with no extras still imports"
printf 'monitor=DP-2,1920x1080@119.88,0x0,1.0\n' >"$WORK/nwg-plain.conf"
ds_from_nwg_conf "$WORK/nwg-plain.conf" "$n_dual" >"$WORK/nwg-plain.layout.json" 2>/dev/null \
  && pass_msg || fail "a plain arrangement must import"

summary "test-display-store"
