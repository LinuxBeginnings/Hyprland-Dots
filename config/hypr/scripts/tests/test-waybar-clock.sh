#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Issue #163: a fresh install that kept 24H left several Waybar clocks on
#   12H, so TOP-Default-Laptop showed a 12H clock beside a 24H format-alt.
#
#   The pairs below are a second, independent copy of the list in
#   ToggleWaybarTime.sh. That is deliberate: asserting them against the shipped
#   files is what catches a pair edited on one side only, which is the failure
#   that started this. The installer's own sed patterns had drifted off the
#   modules files and matched nothing, so its answer changed nothing.
#
#   Everything runs against a sandbox copy of the tree. Waybar is never
#   restarted (--no-restart) and SDDM is stubbed, because prompt_clock_format
#   reaches /usr/share through sudo.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

SCRIPT="$SCRIPT_DIR/ToggleWaybarTime.sh"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
SHIPPED_WAYBAR="$REPO_ROOT/config/hypr/waybar"
LIB_PROMPTS="$REPO_ROOT/scripts/lib_prompts.sh"

WORK="$(mktemp -d)"
trap 'rm -rf -- "$WORK"' EXIT

# Keep the run off the real session bus: notify_swaync probes XDG_RUNTIME_DIR
# for a bus socket, so pointing it at an empty directory means no notification
# can be sent even if a session is live.
export XDG_RUNTIME_DIR="$WORK/runtime"
mkdir -p "$XDG_RUNTIME_DIR"
unset DBUS_SESSION_BUS_ADDRESS

# This suite ships with config/hypr, but the layout files under config/hypr/waybar
# and scripts/lib_prompts.sh are only in a checkout. From
# ~/.config/hypr/scripts/tests neither is present, so say so and report clean
# rather than failing every check for the wrong reason.
if [ ! -f "$LIB_PROMPTS" ] || [ ! -f "$SHIPPED_WAYBAR/Modules" ]; then
  it "the dotfiles tree is not present here (repo-only test)"
  pass_msg
  summary "test-waybar-clock"
  exit 0
fi

CLOCK_GLYPH=$'\uf017'
CAL_GLYPH=$'\uf073'

# One entry per clock module key that carries a clock, in the same order as
# ToggleWaybarTime.sh. clock#forest appears twice because two layouts define it.
PAIR_KEYS=(
  "format"     # clock
  "format"     # clock#2
  "format"     # clock#3
  "format"     # clock#4
  "format"     # clock#5
  "format"     # clock#vertical
  "format"     # clock#forest, TOP-Everforest
  "format"     # clock#forest, TOP-Everforest-glass
  "format"     # clock#text, Matt-Legacy-config
  "format-alt" # clock
  "format-alt" # clock#2
  "format-alt" # clock#5
)

PAIR_12H=(
  "$CLOCK_GLYPH {:%I:%M %p}"
  "$CLOCK_GLYPH {:%I:%M %p}"
  '{:L%I:%M %p - %d/%b}'
  '{:L%B | %a %d, %Y | %I:%M %p}'
  '{:%A, %I:%M %P}'
  "$CLOCK_GLYPH\n{:%I\n%M\n%p\n\n$CAL_GLYPH \n%d\n%m\n%y}"
  '{:L%A %d.%m.%Y - %I:%M %p}'
  '{:L%A %d.%m.%Y - %I:%M %p}'
  '{:%I:%M %p}'
  "$CLOCK_GLYPH {:L%I:%M %p  $CAL_GLYPH %Y, %d %B, %A}"
  '{:L%A  |  %I:%M %p  |  %e %B}'
  '{:L%A, %d %B, %Y (%I:%M %p)}'
)

PAIR_24H=(
  "$CLOCK_GLYPH {:%H:%M:%S}"
  "$CLOCK_GLYPH  {:%H:%M}"
  '{:L%H:%M - %d/%b}'
  '{:L%B | %a %d, %Y | %H:%M}'
  '{:%a %d | %H:%M}'
  "$CLOCK_GLYPH\n{:%H\n%M\n%S\n\n$CAL_GLYPH \n%d\n%m\n%y}"
  '{:L%A %d.%m.%Y - %H:%M}'
  '{:L%A %d.%m.%Y - %H:%M}'
  '{:%H:%M}'
  "$CLOCK_GLYPH {:L%H:%M  $CAL_GLYPH %Y, %d %B, %A}"
  '{:L%A  |  %H:%M  |  %e %B}'
  '{:L%A, %d %B, %Y (%R)}'
)

# seed_tree <dir> - the shipped modules, the layouts that carry their own clock
# and the hyprlock templates, laid out the way the installer sees them.
seed_tree() {
  local d="$1"
  mkdir -p "$d/config/hypr/waybar/configs" "$d/config/hypr/scripts"
  cp "$SHIPPED_WAYBAR/Modules" "$SHIPPED_WAYBAR/ModulesVertical" \
    "$d/config/hypr/waybar/"
  cp "$SHIPPED_WAYBAR/configs/TOP-Everforest" \
    "$SHIPPED_WAYBAR/configs/TOP-Everforest-glass" \
    "$SHIPPED_WAYBAR/configs/Matt-Legacy-config" \
    "$d/config/hypr/waybar/configs/"
  cp "$SCRIPT" "$d/config/hypr/scripts/ToggleWaybarTime.sh"
  cp "$REPO_ROOT/config/hypr/hyprlock.conf" \
    "$REPO_ROOT/config/hypr/hyprlock-1080p.conf" \
    "$REPO_ROOT/config/hypr/hyprlock-2k.conf" \
    "$d/config/hypr/"
}

# Sets WAYBAR_FILES to the sandbox files that carry a clock.
waybar_files() {
  WAYBAR_FILES=(
    "$1/config/hypr/waybar/Modules"
    "$1/config/hypr/waybar/ModulesVertical"
    "$1/config/hypr/waybar/configs/TOP-Everforest"
    "$1/config/hypr/waybar/configs/TOP-Everforest-glass"
    "$1/config/hypr/waybar/configs/Matt-Legacy-config"
  )
}

# The quoted value has to sit on an uncommented format/format-alt line. Matching
# the surrounding quotes is what keeps clock#text's "{:%I:%M %p}" from being
# satisfied by clock's " {:%I:%M %p}".
is_active() {
  grep -hF -- "\"$1\"" "${WAYBAR_FILES[@]}" 2>/dev/null |
    grep -qE '^[[:space:]]*"format(-alt)?"'
}

is_commented() {
  grep -hF -- "\"$1\"" "${WAYBAR_FILES[@]}" 2>/dev/null |
    grep -qE '^[[:space:]]*//[[:space:]]*"format(-alt)?"'
}

# assert_every <12h|24h> <dir> <label> - every pair has that format live and its
# partner commented. Returns non-zero when any pair is wrong; the failures are
# reported here, so the caller only decides whether to print pass_msg.
assert_every() {
  local want="$1" dir="$2" label="$3" i bad=0
  waybar_files "$dir"
  for i in "${!PAIR_KEYS[@]}"; do
    if [ "$want" = "24h" ]; then
      is_active "${PAIR_24H[$i]}" ||
        { fail "$label: pair $i (${PAIR_KEYS[$i]}) is not on 24H: ${PAIR_24H[$i]}"; bad=1; }
      is_commented "${PAIR_12H[$i]}" ||
        { fail "$label: pair $i (${PAIR_KEYS[$i]}) has no commented 12H partner"; bad=1; }
    else
      is_active "${PAIR_12H[$i]}" ||
        { fail "$label: pair $i (${PAIR_KEYS[$i]}) is not on 12H: ${PAIR_12H[$i]}"; bad=1; }
      is_commented "${PAIR_24H[$i]}" ||
        { fail "$label: pair $i (${PAIR_KEYS[$i]}) has no commented 24H partner"; bad=1; }
    fi
  done
  return "$bad"
}

# The discriminator on the live hour line of a hyprlock file: H for 24H, I for
# 12H. Empty when there is no live hour line, which is itself a failure.
hyprlock_hour() {
  local line
  line="$(grep -ohE '^[[:space:]]*text = cmd\[update:1000\] echo "\$\(date \+"%[HI]' "$1" 2>/dev/null | head -1)"
  printf '%s' "${line: -1}"
}

# The discriminator on the commented-out hour line, which has to exist for the
# choice to be reversible.
hyprlock_spare_hour() {
  local line
  line="$(grep -ohE '^#[[:space:]]*text = cmd\[update:1000\] echo "\$\(date \+"%[HI]' "$1" 2>/dev/null | head -1)"
  printf '%s' "${line: -1}"
}

run_toggle() {
  local dir="$1"
  shift
  bash "$SCRIPT" --dir "$dir/config/hypr/waybar" --no-restart "$@"
}

# prompt_clock_format reads DOTFILES_DIR, so it is set for the call and put back
# afterwards rather than exported once and leaking into later checks.
run_prompt() {
  local dir="$1" answer="$2" saved="${DOTFILES_DIR:-}"
  DOTFILES_DIR="$dir"
  prompt_clock_format "$dir/prompt.log" <<<"$answer" >/dev/null 2>&1
  DOTFILES_DIR="$saved"
}

# --- the shipped tree --------------------------------------------------------
# A hand copy has to be correct too, and the prompt tells the user 24H is the
# default. This is also what catches a pair that exists in the script but not in
# the files, or the reverse.
it "the shipped tree is already on 24H for every clock module"
seed_tree "$WORK/shipped"
if assert_every 24h "$WORK/shipped" "shipped"; then pass_msg; fi

it "the shipped hyprlock templates are already on 24H, with 12H commented out"
for f in "$WORK/shipped/config/hypr/hyprlock.conf" \
  "$WORK/shipped/config/hypr/hyprlock-1080p.conf" \
  "$WORK/shipped/config/hypr/hyprlock-2k.conf"; do
  name="$(basename -- "$f")"
  [ "$(hyprlock_hour "$f")" = "H" ] ||
    fail "$name: the live hour line is not %H"
  [ "$(hyprlock_spare_hour "$f")" = "I" ] ||
    fail "$name: no commented %I:%M %p hour line to switch back to"
done
pass_msg

it "every pair in the list is present in the shipped files"
seed_tree "$WORK/present"
drift="$(run_toggle "$WORK/present" --set 24h 2>&1 >/dev/null)"
if [ -n "$drift" ]; then
  fail "the toggle reported drift: $drift"
else pass_msg; fi

# --- both directions ---------------------------------------------------------
it "--set 12h reaches every clock module"
seed_tree "$WORK/d12"
run_toggle "$WORK/d12" --set 12h >/dev/null 2>&1
waybar_files "$WORK/d12"
left24="$(grep -hE '^[[:space:]]*"format(-alt)?":.*(%H|%R)' "${WAYBAR_FILES[@]}" 2>/dev/null)"
if [ -n "$left24" ]; then
  fail "a clock is still on 24H after --set 12h:"$'\n'"$left24"
elif assert_every 12h "$WORK/d12" "--set 12h"; then pass_msg; fi

it "--set 24h reaches every clock module"
seed_tree "$WORK/d24"
run_toggle "$WORK/d24" --set 24h >/dev/null 2>&1
waybar_files "$WORK/d24"
left12="$(grep -hE '^[[:space:]]*"format(-alt)?":.*%I' "${WAYBAR_FILES[@]}" 2>/dev/null)"
if [ -n "$left12" ]; then
  fail "a clock is still on 12H after --set 24h:"$'\n'"$left12"
elif assert_every 24h "$WORK/d24" "--set 24h"; then pass_msg; fi

# --- a tree the user has already half changed --------------------------------
# The state the installer used to leave behind, and the state a user reaches by
# editing one module by hand. The toggle has to repair it, not just flip the
# module it happens to look at first.
it "--set 24h repairs a tree where one clock is still on 12H"
seed_tree "$WORK/mixed"
waybar_files "$WORK/mixed"
sed -i 's#^\( *\)"format": "{:L%H:%M - %d/%b}"#\1//"format": "{:L%H:%M - %d/%b}"#' \
  "$WORK/mixed/config/hypr/waybar/Modules"
sed -i 's#^\( *\)//\("format": "{:L%I:%M %p - %d/%b}"\)#\1\2#' \
  "$WORK/mixed/config/hypr/waybar/Modules"
if is_active "${PAIR_12H[2]}" && ! is_active "${PAIR_24H[2]}"; then
  run_toggle "$WORK/mixed" --set 24h >/dev/null 2>&1
  if assert_every 24h "$WORK/mixed" "repaired"; then pass_msg; fi
else
  fail "the mixed seed did not put clock#3 on 12H, so this check proves nothing"
fi

# --- idempotence and status --------------------------------------------------
it "applying the same format twice changes nothing the second time"
seed_tree "$WORK/idem"
run_toggle "$WORK/idem" --set 24h >/dev/null 2>&1
waybar_files "$WORK/idem"
first="$(cat "${WAYBAR_FILES[@]}" | cksum)"
run_toggle "$WORK/idem" --set 24h >/dev/null 2>&1
waybar_files "$WORK/idem"
second="$(cat "${WAYBAR_FILES[@]}" | cksum)"
if [ "$first" = "$second" ]; then pass_msg
else fail "the second --set 24h changed the files: $first vs $second"; fi

it "--status agrees with what was last applied"
seed_tree "$WORK/status"
run_toggle "$WORK/status" --set 12h >/dev/null 2>&1
got="$(run_toggle "$WORK/status" --status 2>/dev/null)"
[ "$got" = "12H" ] || fail "--status after --set 12h said '$got'"
run_toggle "$WORK/status" --set 24h >/dev/null 2>&1
got="$(run_toggle "$WORK/status" --status 2>/dev/null)"
[ "$got" = "24H" ] || fail "--status after --set 24h said '$got'"
pass_msg

it "the bare toggle flips away from 24H"
seed_tree "$WORK/flip"
run_toggle "$WORK/flip" --set 24h >/dev/null 2>&1
run_toggle "$WORK/flip" >/dev/null 2>&1
if assert_every 12h "$WORK/flip" "bare toggle"; then pass_msg; fi

# --- the installer -----------------------------------------------------------
it "the installer no longer carries its own clock sed expressions"
if grep -qE 'waybar/Modules' "$LIB_PROMPTS"; then
  fail "lib_prompts.sh still edits the Waybar modules directly"
else pass_msg; fi

it "the installer delegates the Waybar half to the toggle script"
if grep -q 'ToggleWaybarTime.sh' "$LIB_PROMPTS"; then pass_msg
else fail "lib_prompts.sh does not call ToggleWaybarTime.sh"; fi

it "copy.sh still calls the clock prompt"
assert_contains "$REPO_ROOT/copy.sh" 'prompt_clock_format' \
  "the prompt is wired into the installer" && pass_msg

# Functional run of the installer prompt. SDDM is stubbed: the real helper
# reaches /usr/share through sudo, which a test must not do.
# shellcheck disable=SC2034
NOTE="" CAT="" SKY_BLUE="" ERROR="" OK="" WARN="" INFO="" RESET=""
# shellcheck source=../../../scripts/lib_prompts.sh
source "$LIB_PROMPTS"

SDDM_LOG="$WORK/sddm.log"
: >"$SDDM_LOG"
apply_sddm_12h_format() { printf 'sddm-12h %s\n' "$1" >>"$SDDM_LOG"; }
apply_sddm_12h_format_sequoia() { printf 'sddm-12h-sequoia %s\n' "$1" >>"$SDDM_LOG"; }

it "answering 24H at install leaves every clock and the lock screen on 24H"
seed_tree "$WORK/inst24"
run_prompt "$WORK/inst24" "24h"
[ "$(hyprlock_hour "$WORK/inst24/config/hypr/hyprlock.conf")" = "H" ] ||
  fail "hyprlock is not on the 24H hour after answering 24H"
if assert_every 24h "$WORK/inst24" "install 24H"; then pass_msg; fi

it "answering 12H at install leaves every clock and the lock screen on 12H"
seed_tree "$WORK/inst12"
run_prompt "$WORK/inst12" "12h"
[ "$(hyprlock_hour "$WORK/inst12/config/hypr/hyprlock.conf")" = "I" ] ||
  fail "hyprlock is not on the 12H hour after answering 12H"
if assert_every 12h "$WORK/inst12" "install 12H"; then pass_msg; fi

it "an empty answer at install keeps the 24H default"
seed_tree "$WORK/instdefault"
run_prompt "$WORK/instdefault" ""
if assert_every 24h "$WORK/instdefault" "install default"; then pass_msg; fi

it "the hyprlock hour survives being switched back and forth"
seed_tree "$WORK/lock"
run_prompt "$WORK/lock" "12h"
run_prompt "$WORK/lock" "24h"
got="$(hyprlock_hour "$WORK/lock/config/hypr/hyprlock.conf")"
[ "$got" = "H" ] || fail "the hour after 12h then 24h is '$got', expected H"
[ "$(hyprlock_spare_hour "$WORK/lock/config/hypr/hyprlock.conf")" = "I" ] ||
  fail "the commented %I line was lost by the round trip"
pass_msg

it "the 12H answer still reaches SDDM"
seed_tree "$WORK/sddm"
run_prompt "$WORK/sddm" "12h"
assert_contains "$SDDM_LOG" 'sddm-12h /usr/share/sddm/themes/simple-sddm' \
  "the SDDM 12H edit ran" && pass_msg

summary "test-waybar-clock"
