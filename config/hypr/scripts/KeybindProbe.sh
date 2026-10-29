#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Find out which keysym each key on your keyboard actually sends.
#
# Why this exists
# ---------------
# A keybind is written against a keysym, not against a key. `Fn+F2` is
# XF86MonBrightnessUp on one laptop and nothing at all on the next, and the
# legends printed on an Fn row are frequently wrong for the Linux keymap.
# Guessing therefore fails quietly: a keysym nothing ever emits produces a bind
# that is registered, listed by `hyprctl binds`, and never fires.
#
# This script asks the compositor instead of the key legend. It installs a probe
# into Hyprland's Lua state that claims a net of candidate keysyms - plus the
# bare function keys - each one logging the keysym Hyprland actually received.
#
# It needs nothing beyond a running Hyprland 0.57+ session: no root, no `wev`,
# no packages. Run --check-deps to see what is missing and how to install it.
#
# How it stays safe
# -----------------
# The probe is loaded with `hyprctl eval`, so it exists only in the running VM
# and is discarded by `hyprctl reload`. No config file is read or written. Every
# chord the probe claims is unbound first, so a keypress while the probe runs
# only logs: no volume change, no suspend, no side effect. The reload on exit
# restores the original binds, and it runs on Ctrl+C and on error too.
#
# Usage:
#   KeybindProbe.sh              press keys, then Enter; prints what each sent
#   KeybindProbe.sh --check-deps report dependencies and install commands
#   KeybindProbe.sh --help

set -uo pipefail

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
PROBE_LUA="$RUNTIME_DIR/kooldots-keyprobe.lua"
PROBE_LOG="$RUNTIME_DIR/kooldots-keyprobe.log"
BINDS_BEFORE="$RUNTIME_DIR/kooldots-keyprobe-binds.txt"
LOCK="$RUNTIME_DIR/kooldots-keyprobe.lock"

# Hyprland grew the Lua config, and with it `hyprctl eval`, in 0.57. Older builds
# parse hyprlang and offer no way to install the probe, so they are pointed at
# `wev` instead of being left with a silent no-op.
PROBE_MIN_VERSION="0.57"

# Keysyms the probe claims. A key that emits something outside this net logs
# nothing, which is itself an answer: it is not a standard media key. Widen the
# list if a key you care about stays silent.
CANDIDATES=(
  # bare function keys: separates a "traditional" row from a "media" row
  F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12
  # display and keyboard brightness
  XF86MonBrightnessUp XF86MonBrightnessDown XF86MonBrightnessCycle
  XF86KbdBrightnessUp XF86KbdBrightnessDown XF86KbdLightOnOff
  # audio and playback
  XF86AudioRaiseVolume XF86AudioLowerVolume XF86AudioMute XF86AudioMicMute
  XF86AudioPlay XF86AudioPause XF86AudioNext XF86AudioPrev
  XF86AudioStop XF86AudioMedia
  # other keys a laptop or multimedia keyboard may send
  XF86Display XF86TouchpadToggle XF86TouchpadOn XF86TouchpadOff
  XF86WLAN XF86Bluetooth XF86Battery XF86Suspend XF86Sleep XF86Rfkill
  XF86Launch1 XF86Launch2 XF86Launch3 XF86Launch4
)

usage() {
  sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# \{0,1\}//'
}

die() {
  printf 'KeybindProbe.sh: %s\n' "$1" >&2
  exit 1
}

# Prints the running Hyprland version, e.g. 0.57.0, or nothing when it cannot be
# determined. The JSON field is clean; the plain output's first line reads
# "Hyprland 0.57.0 built from ...", so field 2 holds the same value.
hyprland_version() {
  local raw=""

  raw="$(hyprctl -j version 2>/dev/null | jq -r '.version // empty' 2>/dev/null || true)"
  if [[ -z "$raw" ]]; then
    raw="$(hyprctl version 2>/dev/null | awk 'NR==1{print $2}')"
    # Field 2 is the version only on the real "Hyprland <ver> built from ..."
    # line. Anything else means the output was not what we expected, so report
    # unknown rather than feed nonsense to the comparison.
    [[ "$raw" =~ ^[0-9] ]] || raw=""
  fi

  printf '%s' "$raw"
}

# Returns 0 when the probe can be installed, 1 when Hyprland is too old, 2 when
# the version could not be determined. Only the major.minor pair is compared, so
# 0.57, 0.57.0, 0.57.0.r12.gabc1234 and 0.58.0-1 all parse the same way.
probe_support() {
  local v major minor rest
  local want_major="${PROBE_MIN_VERSION%%.*}"
  local want_minor="${PROBE_MIN_VERSION#*.}"

  v="$(hyprland_version)"
  [[ -n "$v" ]] || return 2

  v="${v#v}"
  major="${v%%.*}"
  rest="${v#*.}"
  minor="${rest%%.*}"

  [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ ]] || return 2

  (( major > want_major )) && return 0
  (( major == want_major && minor >= want_minor )) && return 0

  return 1
}

# Reads ID from /etc/os-release. Gentoo quotes its values with single quotes, so
# both quote styles are stripped - the same trap that broke the dots upgrade
# detector, see CHANGELOG v2.3.29.
distro_id() {
  local id=""

  if [[ -r /etc/os-release ]]; then
    # shellcheck source=/dev/null
    id="$(. /etc/os-release && printf '%s' "${ID:-}")"
    id="${id%\'}"; id="${id#\'}"
    id="${id%\"}"; id="${id#\"}"
  fi

  printf '%s' "${id:-unknown}"
}

# Collapses the distro ID to the package manager that matters.
distro_family() {
  case "$(distro_id)" in
    debian | ubuntu | linuxmint | zorin | pop | raspbian | neon) printf 'debian' ;;
    arch | endeavouros | manjaro | cachyos | garuda) printf 'arch' ;;
    fedora | rhel | centos | rocky | almalinux) printf 'fedora' ;;
    opensuse* | sles | sled) printf 'opensuse' ;;
    gentoo) printf 'gentoo' ;;
    nixos) printf 'nixos' ;;
    *) printf 'unknown' ;;
  esac
}

# One line per family for everything the docs list as optional or supporting.
# Gentoo is the odd one out: wev and brightnessctl are not in the main tree, so
# they come from the guru overlay and are called out separately.
install_line() {
  case "$(distro_family)" in
    debian) printf 'sudo apt install wev evtest libinput-tools pamixer brightnessctl playerctl libnotify-bin lua5.1' ;;
    arch) printf 'sudo pacman -S wev evtest libinput pamixer brightnessctl playerctl libnotify lua' ;;
    fedora) printf 'sudo dnf install wev evtest libinput pamixer brightnessctl playerctl libnotify lua' ;;
    opensuse) printf 'sudo zypper install wev evtest libinput-tools pamixer brightnessctl playerctl libnotify-tools lua' ;;
    nixos) printf 'nix-shell -p wev evtest pamixer brightnessctl playerctl libnotify lua' ;;
    gentoo) printf 'sudo emerge -av app-misc/evtest media-sound/pamixer media-sound/playerctl x11-libs/libnotify dev-lang/lua' ;;
    *) printf 'wev evtest pamixer brightnessctl playerctl libnotify lua' ;;
  esac
}

report_tool() {
  local tool="$1" why="$2"

  if command -v "$tool" >/dev/null 2>&1; then
    printf '  [ ok ]  %-16s %s\n' "$tool" "$why"
  else
    printf '  [miss]  %-16s %s\n' "$tool" "$why"
  fi
}

check_deps() {
  local family
  family="$(distro_family)"

  printf 'KeybindProbe.sh dependency check\n'
  printf 'Detected distro: %s (family: %s)\n' "$(distro_id)" "$family"
  printf 'Hyprland: %s\n\n' "$(hyprland_version)"

  printf 'Required by the probe itself\n'
  report_tool hyprctl "the probe is installed through it"
  if command -v hyprctl >/dev/null 2>&1; then
    probe_support
    case "$?" in
      0) printf '  [ ok ]  %-16s %s\n' "hyprctl eval" "needs Hyprland $PROBE_MIN_VERSION or newer" ;;
      1) printf '  [miss]  %-16s %s\n' "hyprctl eval" "Hyprland is older than $PROBE_MIN_VERSION; use wev" ;;
      *) printf '  [ ?  ]  %-16s %s\n' "hyprctl eval" "could not determine the Hyprland version" ;;
    esac
  fi

  printf '\nOptional, for the probe\n'
  report_tool wev "alternative inspector, needed only below Hyprland $PROBE_MIN_VERSION"
  report_tool evtest "raw kernel keycodes, needs root"
  report_tool jq "cleaner Hyprland version parsing"

  printf '\nCalled by the media keybinds this script helps you write\n'
  report_tool pamixer "scripts/Volume.sh"
  report_tool brightnessctl "scripts/Brightness.sh and BrightnessKbd.sh"
  report_tool playerctl "scripts/MediaCtrl.sh"
  report_tool notify-send "the on screen display the scripts raise"

  printf '\nTo validate an edited user_keybinds.lua\n'
  report_tool luac "luac -p ~/.config/hypr/UserConfigs/user_keybinds.lua"

  printf '\nInstall everything above for this distro:\n  %s\n' "$(install_line)"
  if [[ "$family" == "gentoo" ]]; then
    printf '\nGentoo note: wev and brightnessctl are not in the main tree.\n'
    printf '  eselect repository enable guru && emerge --sync guru\n'
    printf '  sudo emerge -av gui-apps/wev app-misc/brightnessctl\n'
    printf 'The probe itself needs none of this, so it runs on Gentoo as is.\n'
  fi
  if [[ "$family" == "nixos" ]]; then
    printf '\nNixOS note: this is a declarative distro, so add the packages to\n'
    printf 'environment.systemPackages rather than installing them ad hoc.\n'
  fi
  if [[ "$family" == "unknown" ]]; then
    printf '\nDistro not recognised, so the package names are up to you to map.\n'
  fi
}

# Builds the probe. The candidate list is injected as a Lua table so the list
# lives in exactly one place - the CANDIDATES array above.
write_probe() {
  local lua_list="" key

  for key in "${CANDIDATES[@]}"; do
    lua_list+="  \"${key}\","$'\n'
  done

  cat >"$PROBE_LUA" <<LUA
-- Generated by scripts/KeybindProbe.sh. Do not edit, do not keep.
--
-- Claims a net of candidate keysyms, each logging the keysym Hyprland actually
-- received. Every chord is unbound before it is claimed, so a keypress while
-- this is loaded has no side effect: it logs, and nothing else happens. The
-- probe lives only in the running VM and is discarded by a hyprctl reload.
--
-- Keep this heredoc free of backticks: it is unquoted so the candidate list can
-- be expanded, which means a backtick pair here runs as a command substitution.
local log = "${PROBE_LOG}"

local candidates = {
${lua_list}}

local function claim(key)
  -- Both unbind forms. Builds differ in which one they honour and some no-op
  -- the other silently, the same reason user_keybinds_helper.lua calls both.
  pcall(hl.unbind, key)
  pcall(hl.unbind, "", key)
  return pcall(hl.bind, key, function()
    hl.exec_cmd("echo " .. key .. " >> " .. log)
  end, { description = "KEYPROBE " .. key, locked = true })
end

-- Truncate first: a line left over from an earlier run must not read as a
-- keypress, and that is what an append-only log would do.
hl.exec_cmd(": > " .. log)

local claimed = 0
for _, key in ipairs(candidates) do
  if claim(key) then claimed = claimed + 1 end
end

print("keyprobe: " .. claimed .. "/" .. #candidates .. " keysyms claimed")
LUA
}

cleanup() {
  # Reloading drops the probe with the VM and brings back the original binds.
  # Nothing was written to disk, so there is nothing else to undo.
  hyprctl reload >/dev/null 2>&1 || true
  rm -f -- "$PROBE_LUA" "$PROBE_LOG" "$BINDS_BEFORE"
}

# True when the keysym already had a bind before the probe was installed.
# Matches the plain `hyprctl binds` output, which prints one "key: <name>" line
# per bind, so this needs no jq.
already_bound() {
  grep -qE "^[[:space:]]*key: $1\$" "$BINDS_BEFORE" 2>/dev/null
}

report() {
  local line key count
  local -A presses=()
  local -A seen=()
  local order=()

  # One pass: count every press and keep first-seen order for the listing.
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    presses["$line"]=$(( ${presses["$line"]:-0} + 1 ))
    if [[ -z "${seen["$line"]:-}" ]]; then
      seen["$line"]=1
      order+=("$line")
    fi
  done <"$PROBE_LOG"

  printf '\n'
  if (( ${#order[@]} == 0 )); then
    printf 'No keysyms captured.\n'
    printf 'Either nothing was pressed, or every key emits a keysym outside the probe net.\n'
    printf 'Add the keysym to CANDIDATES in %s and run again.\n' "$0"
    return 0
  fi

  printf '%-28s %-12s %s\n' 'KEYSYM' 'PRESSES' 'STATE'
  for key in "${order[@]}"; do
    count="${presses["$key"]}"
    if already_bound "$key"; then
      printf '%-28s %-12s %s\n' "$key" "$count" 'already bound'
    else
      printf '%-28s %-12s %s\n' "$key" "$count" 'not bound - add a bind if you want it'
    fi
  done

  printf '\nEdit ~/.config/hypr/UserConfigs/user_keybinds.lua to use these.\n'
  printf 'Call unbind("", "KEYSYM") before each bind(...): re-binding a chord that\n'
  printf 'already exists keeps both, and the key then fires twice.\n'
  printf 'See docs/HOWTO-Keyboard-Mappings.md.\n'
}

case "${1:-}" in
  --check-deps | --deps)
    check_deps
    exit 0
    ;;
  --help | -h)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    die "unknown option: $1 (try --help)"
    ;;
esac

command -v hyprctl >/dev/null 2>&1 || die "hyprctl not found. Run this inside a Hyprland session."

if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  die "no Hyprland instance in this environment. Run this from a terminal inside Hyprland."
fi

probe_support
case "$?" in
  0) ;;
  1)
    die "Hyprland $(hyprland_version) is older than $PROBE_MIN_VERSION, so it has no 'hyprctl eval' to install the probe with.
Use 'wev' instead: run wev, press each key, and read the sym: field."
    ;;
  *)
    die "could not determine the Hyprland version, so the probe was not installed."
    ;;
esac

# One probe at a time. Guarded because flock is util-linux, which is not
# universal on a minimal NixOS install.
if command -v flock >/dev/null 2>&1; then
  exec 200>"$LOCK" 2>/dev/null || true
  flock -n 200 2>/dev/null || die "another KeybindProbe.sh is already running."
fi

# Snapshot the binds before claiming anything, so the summary can say which
# keysyms already had a bind and which are new.
hyprctl binds >"$BINDS_BEFORE" 2>/dev/null || : >"$BINDS_BEFORE"

write_probe || die "could not write the probe to $PROBE_LUA"

# From here on every exit path has to undo the probe, including Ctrl+C.
trap cleanup EXIT
trap 'exit 130' INT TERM

# Only the exact reply 'ok' counts as a successful write. hyprctl can exit 0
# while answering something else, which is how the Rainbow Borders write was
# silently lost on 0.57 - see CHANGELOG v2.3.29.
reply="$(hyprctl eval "dofile(\"$PROBE_LUA\")" 2>&1)"
if [[ "$reply" != "ok" ]]; then
  die "hyprctl eval did not answer 'ok', so the probe was not installed. Reply: $reply"
fi

printf '\nPress each key you want to identify, one at a time.\n'
printf 'Bare F1-F12 are claimed by the probe, so they will not reach the focused\n'
printf 'window until it is removed. Press Enter when you are done.\n\n'
read -r _ignored || true

report
