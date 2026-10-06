#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   The parameter table: one row per connected monitor, plus the things no
#   external tool can express for us — which monitor is primary, which are
#   switched off, and where the Waybar bars go.
#
#     DisplayProfileSetup.sh [-- <layout-name>]
#
#   Without a name it starts from the live state; with one it edits that saved
#   layout. It must be able to author a layout for a state you are NOT in,
#   which is how a laptop-only layout gets created without first blanking the
#   external monitor.
#
#   Positions are never typed. You choose a row, an order within the row and a
#   vertical alignment, and the coordinates are computed from the logical sizes
#   (mode / scale). That removes the arithmetic that made the old hardcoded
#   position wrong whenever a scale changed.
#
#   rofi is asked for an index (-format i) and the index is looked up in a
#   parallel array of actions. No eval.
set -Eeuo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

DPS_PROFILE_SCRIPT="${DPS_PROFILE_SCRIPT:-$config_home/hypr/scripts/DisplayProfile.sh}"
DPS_LAUNCHER="${DPS_LAUNCHER:-rofi}"
DPS_ROFI_CONFIG="${DPS_ROFI_CONFIG:-$config_home/hypr/rofi/config-Monitors.rasi}"
DPS_JQ="${DPS_JQ:-jq}"
DPS_NOTIFY="${DPS_NOTIFY:-notify-send}"
DPS_STORE_FILE="${DPS_STORE_FILE:-$config_home/hypr/UserConfigs/display-layouts.json}"
DPS_RUNTIME_DIR="${DPS_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}}"
STATE_DIR="$DPS_RUNTIME_DIR/kooldots-display-profiles"
DPS_LOG_FILE="${DPS_LOG_FILE:-$STATE_DIR/setup.log}"

SCALES=(1 1.25 1.333333 1.5 1.6 1.75 2)
TRANSFORMS=(0 1 2 3)
ROWS_CHOICES=(1 2 3 4)
ORDERS=(1 2 3 4 5 6 7 8)
VALIGNS=(top center bottom)
WAYBAR_MODES=(all primary selected)

# shellcheck source=./lib_display_store.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib_display_store.sh"
DS_JQ="$DPS_JQ"

MON_FILE=""
MON_FP=""
DRAFT=""
LAYOUT_NAME=""

log() {
  local line
  line="$(date '+%Y-%m-%d %H:%M:%S') [DisplayProfileSetup] $*"
  printf '%s\n' "$line" >&2
  mkdir -p -- "$(dirname -- "$DPS_LOG_FILE")" 2>/dev/null || return 0
  printf '%s\n' "$line" >>"$DPS_LOG_FILE" 2>/dev/null || true
}

notify() {
  command -v "$DPS_NOTIFY" >/dev/null 2>&1 || return 0
  "$DPS_NOTIFY" -a "Display layouts" "$1" "${2:-}" >/dev/null 2>&1 || true
}

ask_index() {
  local mesg=$1 prompt=$2; shift 2
  local -a args=(-i -dmenu -format i -p "$prompt" -mesg "$mesg")
  [[ -r $DPS_ROFI_CONFIG ]] && args+=(-config "$DPS_ROFI_CONFIG")
  printf '%s\n' "$@" | "$DPS_LAUNCHER" "${args[@]}" 2>/dev/null || true
}

ask_text() {
  local prompt=$1
  local -a args=(-dmenu -p "$prompt")
  [[ -r $DPS_ROFI_CONFIG ]] && args+=(-config "$DPS_ROFI_CONFIG")
  printf '' | "$DPS_LAUNCHER" "${args[@]}" 2>/dev/null || true
}

# pick <mesg> <prompt> <choices...> -> the chosen value, or nothing
pick() {
  local mesg=$1 prompt=$2; shift 2
  local -a choices=("$@")
  local idx
  idx="$(ask_index "$mesg" "$prompt" "${choices[@]}")"
  idx="${idx%%[^0-9]*}"
  [[ $idx =~ ^[0-9]+$ ]] || return 1
  (( idx >= 0 && idx < ${#choices[@]} )) || return 1
  printf '%s\n' "${choices[$idx]}"
}

# --- the draft -------------------------------------------------------------
load_monitors() {
  MON_FILE="$("$DPS_PROFILE_SCRIPT" monitors-json 2>/dev/null | tail -n1 || true)"
  [[ -n $MON_FILE && -f $MON_FILE ]] || { log "cannot read the monitor list"; return 1; }
  MON_FP="$(ds_fingerprint "$MON_FILE")"
  [[ -n $MON_FP ]] || { log "no monitors connected"; return 1; }
}

load_draft() {
  local name=${1-}
  mkdir -p -- "$STATE_DIR"
  DRAFT="$STATE_DIR/setup-draft.json"
  if [[ -n $name ]] && ds_layout_names "$MON_FILE" "$DPS_STORE_FILE" | grep -qxF -- "$name"; then
    LAYOUT_NAME="$name"
    ds_store_read "$DPS_STORE_FILE" \
      | "$DS_JQ" -c --arg fp "$MON_FP" --arg n "$name" '.fingerprints[$fp].layouts[$n]' >"$DRAFT"
    ds_assign_ports "$DRAFT" "$MON_FILE" >"$DRAFT.n" && mv -f -- "$DRAFT.n" "$DRAFT"
    log "editing the saved layout $name"
  else
    LAYOUT_NAME=""
    ds_capture "$MON_FILE" >"$DRAFT"
    log "starting from the live state"
  fi
}

recompute() { ds_apply_grid "$DRAFT" >"$DRAFT.n" && mv -f -- "$DRAFT.n" "$DRAFT"; }

# edit_monitor <index> <jq-assignment>
edit_monitor() {
  local i=$1 assign=$2
  "$DS_JQ" -c --argjson i "$i" ".monitors[\$i] |= ($assign)" -- "$DRAFT" >"$DRAFT.n" \
    && mv -f -- "$DRAFT.n" "$DRAFT"
  recompute
}

# --- labels ----------------------------------------------------------------
monitor_label() {  # index -> "Make Model (PORT)   on · mode · x1.5 · row 1 · order 2 · top"
  local i=$1
  "$DS_JQ" -r --slurpfile live "$MON_FILE" --argjson i "$i" '
    .monitors[$i] as $m
    | ( [ $live[0][] | select(.identity == $m.identity) ] | .[0] ) as $l
    | ( (($l.make // "") + " " + ($l.model // "")) | gsub("^ +| +$"; "") ) as $name
    | ( if $name == "" then $m.identity else $name end )
      + " (" + $m.port + ")   "
      + (if $m.enabled then "on" else "off" end)
      + " · " + $m.mode
      + " · x" + ($m.scale | tostring)
      + (if ($m.transform // 0) != 0 then " · rotated " + (($m.transform // 0) | tostring) else "" end)
      + " · row " + (($m.grid.row // 1) | tostring)
      + " · order " + (($m.grid.order // 1) | tostring)
      + " · " + ($m.grid.valign // "top")
  ' -- "$DRAFT"
}

primary_label() {
  "$DS_JQ" -r --slurpfile live "$MON_FILE" '
    .primary as $p
    | ( [ $live[0][] | select(.identity == $p) ] | .[0] ) as $l
    | ( (($l.make // "") + " " + ($l.model // "")) | gsub("^ +| +$"; "") ) as $name
    | if $name == "" then $p else $name end
  ' -- "$DRAFT"
}

waybar_label() {
  "$DS_JQ" -r '
    (.waybar.mode // "all") as $m
    | if $m == "selected"
      then "selected → " + (((.waybar.outputs // []) | length | tostring) + " monitor(s)")
      else $m end
  ' -- "$DRAFT"
}

position_label() {
  "$DS_JQ" -r '[ .monitors[] | select(.enabled == true)
                 | .port + " " + ((.x // 0) | tostring) + "x" + ((.y // 0) | tostring) ]
               | join(" · ")' -- "$DRAFT"
}

monitor_count() { "$DS_JQ" -r '.monitors | length' -- "$DRAFT"; }

# --- the monitor submenu ---------------------------------------------------
monitor_menu() {
  local i=$1 n choice mode scale transform row order valign enabled
  n="$(monitor_label "$i")"
  while true; do
    enabled="$("$DS_JQ" -r --argjson i "$i" '.monitors[$i].enabled' -- "$DRAFT")"
    choice="$(pick "$n" "Monitor" \
      "$([[ $enabled == true ]] && echo 'Switch this monitor off' || echo 'Switch this monitor on')" \
      "Mode" "Scale" "Rotation" "Row" "Order within the row" "Vertical alignment" "Back")" || return 0
    case $choice in
      'Switch this monitor off') edit_monitor "$i" '.enabled = false'; return 0 ;;
      'Switch this monitor on')  edit_monitor "$i" '.enabled = true';  return 0 ;;
      Mode)
        local -a modes=()
        mapfile -t modes < <("$DS_JQ" -r --slurpfile live "$MON_FILE" --argjson i "$i" '
          .monitors[$i].identity as $id
          | [ $live[0][] | select(.identity == $id) | .modes[]? ] | unique | reverse | .[]' -- "$DRAFT")
        if (( ${#modes[@]} == 0 )); then
          notify "Display layouts" "This monitor reports no modes; leaving it as it is"
          return 0
        fi
        mode="$(pick "$n" "Mode" "${modes[@]}")" || return 0
        edit_monitor "$i" "$(printf '.mode = "%s"' "$mode")"
        return 0
        ;;
      Scale)
        scale="$(pick "$n" "Scale" "${SCALES[@]}")" || return 0
        edit_monitor "$i" "$(printf '.scale = %s' "$scale")"
        return 0
        ;;
      Rotation)
        transform="$(pick "$n" "Rotation (0 none, 1 = 90°, 2 = 180°, 3 = 270°)" "${TRANSFORMS[@]}")" || return 0
        edit_monitor "$i" "$(printf '.transform = %s' "$transform")"
        return 0
        ;;
      Row)
        row="$(pick "$n" "Row" "${ROWS_CHOICES[@]}")" || return 0
        edit_monitor "$i" "$(printf '.grid.row = %s' "$row")"
        return 0
        ;;
      'Order within the row')
        order="$(pick "$n" "Order" "${ORDERS[@]}")" || return 0
        edit_monitor "$i" "$(printf '.grid.order = %s' "$order")"
        return 0
        ;;
      'Vertical alignment')
        valign="$(pick "$n" "Vertical alignment" "${VALIGNS[@]}")" || return 0
        edit_monitor "$i" "$(printf '.grid.valign = "%s"' "$valign")"
        return 0
        ;;
      Back) return 0 ;;
    esac
  done
}

primary_menu() {
  local -a names=() ids=()
  mapfile -t names < <("$DS_JQ" -r --slurpfile live "$MON_FILE" '
    .monitors[] | .identity as $id
    | ( [ $live[0][] | select(.identity == $id) ] | .[0] ) as $l
    | ( (($l.make // "") + " " + ($l.model // "")) | gsub("^ +| +$"; "") ) as $name
    | (if $name == "" then $id else $name end) + " (" + .port + ")"' -- "$DRAFT")
  mapfile -t ids < <("$DS_JQ" -r '.monitors[].identity' -- "$DRAFT")
  local idx
  idx="$(ask_index "Which monitor should be focused after this layout is applied?" \
         "Primary" "${names[@]}")"
  idx="${idx%%[^0-9]*}"
  [[ $idx =~ ^[0-9]+$ ]] || return 0
  (( idx >= 0 && idx < ${#ids[@]} )) || return 0
  "$DS_JQ" -c --arg p "${ids[$idx]}" '.primary = $p' -- "$DRAFT" >"$DRAFT.n" && mv -f -- "$DRAFT.n" "$DRAFT"
}

waybar_menu() {
  local mode
  mode="$(pick "Where should the bars appear?" "Waybar" "${WAYBAR_MODES[@]}")" || return 0
  if [[ $mode != selected ]]; then
    "$DS_JQ" -c --arg m "$mode" '.waybar = { mode: $m, outputs: [] }' -- "$DRAFT" >"$DRAFT.n" \
      && mv -f -- "$DRAFT.n" "$DRAFT"
    return 0
  fi
  # "selected" is built up one monitor at a time: rofi's multi-select is not
  # available in every theme these dots ship.
  local -a names=() ids=()
  mapfile -t ids < <("$DS_JQ" -r '.monitors[].identity' -- "$DRAFT")
  local chosen=() id idx
  while true; do
    names=()
    for id in "${ids[@]}"; do
      local mark=" "
      for c in ${chosen[@]+"${chosen[@]}"}; do [[ $c == "$id" ]] && mark="✓"; done
      names+=("$mark $id")
    done
    names+=("Done")
    idx="$(ask_index "Pick the monitors that should show a bar" "Waybar outputs" "${names[@]}")"
    idx="${idx%%[^0-9]*}"
    [[ $idx =~ ^[0-9]+$ ]] || break
    (( idx >= 0 && idx < ${#names[@]} )) || break
    (( idx == ${#names[@]} - 1 )) && break
    chosen+=("${ids[$idx]}")
  done
  local json
  json="$(printf '%s\n' ${chosen[@]+"${chosen[@]}"} | "$DS_JQ" -R -s -c 'split("\n") | map(select(length > 0)) | unique')"
  "$DS_JQ" -c --argjson out "$json" '.waybar = { mode: "selected", outputs: $out }' -- "$DRAFT" >"$DRAFT.n" \
    && mv -f -- "$DRAFT.n" "$DRAFT"
}

# --- saving ----------------------------------------------------------------
save_and_apply() {
  local name=$LAYOUT_NAME
  if [[ -z $name ]]; then
    name="$(ask_text 'Save this layout as')"
    name="${name%$'\n'}"
    if [[ -z $name ]]; then log "no name given; nothing saved"; return 1; fi
    if ! ds_name_valid "$name"; then
      log "refusing the name '$name'"
      notify "Display layouts" "That name has characters I cannot store. Letters, digits, space . - _ only."
      return 1
    fi
  fi
  recompute
  if ! ds_validate_layout "$DRAFT" 2>/dev/null; then
    log "this layout cannot be applied: every monitor is disabled, or a value is out of range"
    notify "Display layouts" "Every monitor is disabled — switch at least one back on"
    return 1
  fi
  if ! ds_store_set "$DPS_STORE_FILE" "$MON_FP" "$name" "$DRAFT"; then
    log "could not save $name"
    notify "Display layouts" "Could not save $name"
    return 1
  fi
  log "saved $name; applying it"
  exec "$DPS_PROFILE_SCRIPT" -- "$name"
}

# --- the table -------------------------------------------------------------
table_once() {
  local -a ROWS=() ACTIONS=()
  local i count idx action
  count="$(monitor_count)"
  for (( i = 0; i < count; i++ )); do
    ROWS+=("$(monitor_label "$i")"); ACTIONS+=("monitor:$i")
  done
  ROWS+=("Primary                 $(primary_label)");      ACTIONS+=("primary")
  ROWS+=("Waybar                  $(waybar_label)");       ACTIONS+=("waybar")
  ROWS+=("Position (computed)     $(position_label)");     ACTIONS+=("noop")
  ROWS+=("Save & apply");                                  ACTIONS+=("save")
  ROWS+=("Cancel");                                        ACTIONS+=("cancel")

  local mesg="Monitor set: $MON_FP"
  [[ -n $LAYOUT_NAME ]] && mesg="Layout: $LAYOUT_NAME · $mesg"
  idx="$(ask_index "$mesg" "Display parameters" "${ROWS[@]}")"
  idx="${idx%%[^0-9]*}"
  [[ $idx =~ ^[0-9]+$ ]] || return 1
  (( idx >= 0 && idx < ${#ACTIONS[@]} )) || return 1

  action="${ACTIONS[$idx]}"
  case $action in
    monitor:*) monitor_menu "${action#monitor:}"; return 0 ;;
    primary)   primary_menu; return 0 ;;
    waybar)    waybar_menu;  return 0 ;;
    noop)      return 0 ;;
    save)      save_and_apply || return 0; return 1 ;;
    cancel)    log "cancelled; nothing was written"; return 1 ;;
  esac
  return 1
}

main() {
  local name=""
  case "${1-}" in
    --) shift; name=${1-} ;;
    -h | --help) sed -n '9,26p' -- "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; return 0 ;;
    "") : ;;
    *) name=$1 ;;
  esac
  if command -v pgrep >/dev/null 2>&1 && pgrep -x rofi >/dev/null 2>&1; then
    pkill -x rofi >/dev/null 2>&1 || true
    sleep 0.1
  fi
  load_monitors || { notify "Display layouts" "Cannot read the monitor list"; exit 1; }
  load_draft "$name"
  recompute
  while table_once; do :; done
  exit 0
}

main "$@"
