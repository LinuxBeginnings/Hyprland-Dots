#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Launch preferred file manager with fallback handling.
# Usage:
#   LaunchFileManager.sh "<preferred-file-manager-cmd>" "<preferred-terminal-cmd>"
# Examples:
#   LaunchFileManager.sh "thunar" "kitty"

set -u

notify_msg() {
  local urgency="${1:-normal}"
  local body="${2:-}"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u "$urgency" "KooL Launchers" "$body"
  fi
}

trim() {
  local value="${1:-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

command_bin_from_string() {
  local cmd
  cmd="$(trim "${1:-}")"
  [[ -n "$cmd" ]] || return 1
  (
    eval "set -- $cmd"
    printf '%s' "${1:-}"
  ) 2>/dev/null
}

command_exists_from_string() {
  local bin
  bin="$(command_bin_from_string "${1:-}" 2>/dev/null || true)"
  [[ -n "$bin" ]] || return 1
  command -v "$bin" >/dev/null 2>&1
}

launch_command_string() {
  local cmd
  cmd="$(trim "${1:-}")"
  [[ -n "$cmd" ]] || return 1

  if ! command_exists_from_string "$cmd"; then
    return 127
  fi

  (
    eval "exec $cmd"
  ) >/dev/null 2>&1 &
  local pid=$!

  sleep 0.35
  if kill -0 "$pid" >/dev/null 2>&1; then
    disown "$pid" >/dev/null 2>&1 || true
    return 0
  fi

  wait "$pid"
  local rc=$?
  [[ $rc -eq 0 ]]
}

append_unique_candidate() {
  local candidate
  candidate="$(trim "${1:-}")"
  [[ -n "$candidate" ]] || return 0
  local existing
  for existing in "${CANDIDATES[@]}"; do
    [[ "$existing" == "$candidate" ]] && return 0
  done
  CANDIDATES+=("$candidate")
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
terminal_launcher="$script_dir/LaunchTerminal.sh"

preferred_files="$(trim "${1:-${FILE_MANAGER:-}}")"
preferred_term="$(trim "${2:-${TERMINAL:-kitty}}")"

declare -a CANDIDATES=()
append_unique_candidate "$preferred_files"
append_unique_candidate "thunar"
append_unique_candidate "dolphin"
append_unique_candidate "nautilus"

reported_preferred_issue=0

for candidate in "${CANDIDATES[@]}"; do
  if launch_command_string "$candidate"; then
    exit 0
  fi

  if [[ $reported_preferred_issue -eq 0 && -n "$preferred_files" && "$candidate" == "$preferred_files" ]]; then
    if ! command_exists_from_string "$preferred_files"; then
      notify_msg normal "Preferred file manager '$preferred_files' is not installed. Falling back."
    else
      notify_msg normal "Preferred file manager '$preferred_files' failed to launch. Falling back."
    fi
    reported_preferred_issue=1
  fi
done

if command -v yazi >/dev/null 2>&1; then
  if [[ -x "$terminal_launcher" ]] && "$terminal_launcher" "$preferred_term" "yazi"; then
    exit 0
  fi
else
  notify_msg normal "No GUI file manager was launched and 'yazi' is not installed."
fi

notify_msg critical "Unable to launch file manager. Tried preferred app, thunar, dolphin, nautilus, then terminal + yazi."
exit 1
