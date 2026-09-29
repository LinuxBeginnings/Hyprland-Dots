#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Launcher for the Waybar modules (file manager, terminal, btop, nvtop, nmtui).
#
# Defaults are resolved the same way the rest of the repo does it since the
# configs moved to Lua:
#   1. ~/.config/hypr/UserConfigs/user_defaults.lua  (your overrides)
#   2. ~/.config/hypr/lua/user_defaults.lua          (shipped defaults)
#   3. $TERMINAL / $FILE_MANAGER, then sensible fallbacks
#
# The old UserConfigs/01-UserDefaults.conf was removed together with the other
# Hyprlang files, so this script must keep working when it is absent.

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
hypr_dir="$config_home/hypr"
scripts_dir="$hypr_dir/scripts"
user_defaults="$hypr_dir/UserConfigs/user_defaults.lua"
system_defaults="$hypr_dir/lua/user_defaults.lua"
iDIR="$config_home/swaync/images"

notify_msg() {
  local urgency="${1:-low}" body="${2:-}"
  command -v notify-send >/dev/null 2>&1 || return 0
  if [[ -f "$iDIR/error.png" ]]; then
    notify-send -u "$urgency" -i "$iDIR/error.png" "Waybar: launcher" "$body"
  else
    notify-send -u "$urgency" "Waybar: launcher" "$body"
  fi
}

# read_lua_default <key> <file>: value of KOOLDOTS_DEFAULTS.<key>, if set
read_lua_default() {
  local key="$1" file="$2"
  [[ -f "$file" ]] || return 0
  sed -nE "s/^[[:space:]]*KOOLDOTS_DEFAULTS\\.${key}[[:space:]]*=[[:space:]]*[\"']([^\"']*)[\"'].*/\\1/p" "$file" | tail -n1
}

# resolve_default <key> <env-fallback>: user override, then system default, then env
resolve_default() {
  local key="$1" fallback="$2" value=""
  value="$(read_lua_default "$key" "$user_defaults")"
  [[ -z "$value" ]] && value="$(read_lua_default "$key" "$system_defaults")"
  [[ -z "$value" ]] && value="$fallback"
  printf '%s' "$value"
}

term="$(resolve_default term "${TERMINAL:-}")"
term="${term:-kitty}"
files="$(resolve_default files "${FILE_MANAGER:-}")"

# Terminal-backed actions. Prefers LaunchTerminal.sh, which knows the payload
# syntax of each terminal and falls back through the installed ones; the inline
# path only covers installs that predate that script.
launch_terminal() {
  local payload="${1:-}"
  if [[ -x "$scripts_dir/LaunchTerminal.sh" ]]; then
    "$scripts_dir/LaunchTerminal.sh" "$term" "$payload"
    return $?
  fi
  if [[ -n "$payload" ]]; then
    $term --title "$payload" sh -c "$payload"
  else
    $term &
  fi
}

launch_files() {
  if [[ -x "$scripts_dir/LaunchFileManager.sh" ]]; then
    "$scripts_dir/LaunchFileManager.sh" "$files" "$term"
    return $?
  fi
  if [[ -z "$files" ]]; then
    notify_msg low "Set KOOLDOTS_DEFAULTS.files in UserConfigs/user_defaults.lua or install a default file manager."
    return 1
  fi
  eval "$files &"
}

case "${1:-}" in
--btop)
  launch_terminal btop
  ;;
--nvtop)
  launch_terminal nvtop
  ;;
--nmtui)
  launch_terminal nmtui
  ;;
--term)
  launch_terminal
  ;;
--files)
  launch_files
  ;;
*)
  echo "Usage: $0 [--btop | --nvtop | --nmtui | --term | --files]"
  echo "--btop       : Open btop in a new term"
  echo "--nvtop      : Open nvtop in a new term"
  echo "--nmtui      : Open nmtui in a new term"
  echo "--term       : Launch a term window"
  echo "--files      : Launch a file manager"
  echo
  echo "Defaults come from UserConfigs/user_defaults.lua (KOOLDOTS_DEFAULTS.term / .files)"
  ;;
esac
