#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Launch preferred terminal with fallback handling.
# Usage:
#   LaunchTerminal.sh "<preferred-terminal-cmd>" [payload-command]
# Examples:
#   LaunchTerminal.sh "kitty"
#   LaunchTerminal.sh "ghostty" "yazi"

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

shell_quote() {
  local value="${1:-}"
  printf "'%s'" "${value//\'/\'\\\'\'}"
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

build_terminal_command() {
  local term_cmd payload bin q_payload
  term_cmd="$(trim "${1:-}")"
  payload="$(trim "${2:-}")"

  if [[ -z "$payload" ]]; then
    printf '%s' "$term_cmd"
    return 0
  fi

  bin="$(command_bin_from_string "$term_cmd" 2>/dev/null || true)"
  q_payload="$(shell_quote "$payload")"

  case "$bin" in
  gnome-terminal)
    printf '%s -- %s' "$term_cmd" "$q_payload"
    ;;
  wezterm)
    case "$term_cmd" in
    *" start "* | "wezterm start")
      printf '%s -- %s' "$term_cmd" "$q_payload"
      ;;
    *)
      printf '%s start -- %s' "$term_cmd" "$q_payload"
      ;;
    esac
    ;;
  *)
    printf '%s -e %s' "$term_cmd" "$q_payload"
    ;;
  esac
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

preferred_term="$(trim "${1:-${TERMINAL:-}}")"
payload_cmd="$(trim "${2:-}")"

declare -a CANDIDATES=()
append_unique_candidate "$preferred_term"
append_unique_candidate "kitty"
append_unique_candidate "ghostty"
append_unique_candidate "alacritty"
append_unique_candidate "wezterm"
append_unique_candidate "konsole"
append_unique_candidate "gnome-terminal"

reported_preferred_issue=0
candidate_cmd=""

for candidate in "${CANDIDATES[@]}"; do
  candidate_cmd="$(build_terminal_command "$candidate" "$payload_cmd")"
  if launch_command_string "$candidate_cmd"; then
    exit 0
  fi

  if [[ $reported_preferred_issue -eq 0 && -n "$preferred_term" && "$candidate" == "$preferred_term" ]]; then
    if ! command_exists_from_string "$preferred_term"; then
      notify_msg normal "Preferred terminal '$preferred_term' is not installed. Falling back."
    else
      notify_msg normal "Preferred terminal '$preferred_term' failed to launch. Falling back."
    fi
    reported_preferred_issue=1
  fi
done

if [[ -n "$payload_cmd" ]]; then
  notify_msg critical "Unable to launch terminal for command '$payload_cmd'."
else
  notify_msg critical "Unable to launch terminal. Install one of: kitty, ghostty, alacritty, wezterm, konsole, gnome-terminal."
fi

exit 1
