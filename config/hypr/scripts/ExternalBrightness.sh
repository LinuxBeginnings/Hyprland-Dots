#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# External monitor brightness via ddcutil

set -u

step=10
vcp_code=10

usage() {
  cat <<'EOF'
Usage: ExternalBrightness.sh [--get|--inc|--dec|--set N] [--display N]
Env:
  DDCUTIL_DISPLAY  Optional display number passed to ddcutil --display
  DDCUTIL_OPTS     Extra options passed to ddcutil (e.g. "--sleep-multiplier 0.2")
EOF
}

ddcutil_cmd() {
  local display_arg=()
  local display="${DDCUTIL_DISPLAY:-}"
  if [[ -n "${display}" ]]; then
    display_arg+=(--display "${display}")
  fi
  ddcutil ${DDCUTIL_OPTS:-} "${display_arg[@]}" "$@"
}

get_brightness() {
  # Example output: "VCP code 0x10 (Brightness): current value = 50, max value = 100"
  local line
  if ! line="$(ddcutil_cmd getvcp "${vcp_code}" 2>/dev/null | tail -n 1)"; then
    return 1
  fi
  local current max
  current="$(printf "%s" "${line}" | sed -n 's/.*current value = *\([0-9]\+\).*/\1/p')"
  max="$(printf "%s" "${line}" | sed -n 's/.*max value = *\([0-9]\+\).*/\1/p')"
  [[ -n "${current}" && -n "${max}" ]] || return 1
  printf "%s %s\n" "${current}" "${max}"
}

set_brightness() {
  local value="$1"
  ddcutil_cmd setvcp "${vcp_code}" "${value}" >/dev/null 2>&1
}

json_output() {
  local current max percent icon
  if ! read -r current max < <(get_brightness); then
    printf '{"text":"󰃜 N/A","tooltip":"External brightness unavailable (load i2c-dev, allow i2c access)","class":"brightness-external-off"}\n'
    return 0
  fi
  percent=$(( current * 100 / max ))
  if (( percent >= 80 )); then
    icon="󰃠"
  elif (( percent >= 60 )); then
    icon="󰃟"
  elif (( percent >= 40 )); then
    icon="󰃞"
  elif (( percent >= 20 )); then
    icon="󰃝"
  else
    icon=""
  fi
  printf '{"text":"%s %s%%","tooltip":"External display brightness: %s%%","class":"brightness-external"}\n' "${icon}" "${percent}" "${percent}"
}

case "${1:-}" in
  --get|"")
    json_output
    ;;
  --inc|--dec)
    read -r current max < <(get_brightness) || exit 1
    delta=$step
    [[ "$1" == "--dec" ]] && delta=$(( -step ))
    new=$(( current + delta ))
    (( new < 5 )) && new=5
    (( new > max )) && new="${max}"
    set_brightness "${new}"
    json_output
    ;;
  --set)
    [[ -n "${2:-}" ]] || { usage; exit 1; }
    set_brightness "${2}"
    json_output
    ;;
  --display)
    [[ -n "${2:-}" ]] || { usage; exit 1; }
    DDCUTIL_DISPLAY="${2}" shift 2
    "${0}" "${@:-"--get"}"
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
