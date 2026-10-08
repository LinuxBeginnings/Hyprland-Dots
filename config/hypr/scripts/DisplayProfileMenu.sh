#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Popup for the monitor set in front of you: pick one of its saved layouts,
#   arrange the monitors by dragging, save the current arrangement, or edit the
#   parameters in a table.
#
#     DisplayProfileMenu.sh [--dry-run]
#
#   Layout names are the user's own text, so the rows cannot be a fixed list
#   any more. rofi is therefore asked for an INDEX (-format i) and the index is
#   looked up in a parallel array of actions. A layout name is never executed
#   as shell text, and is always passed to the controller after `--` so a name
#   like "-n" cannot be read as an option. No eval.
set -Eeuo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

DPM_PROFILE_SCRIPT="${DPM_PROFILE_SCRIPT:-$config_home/hypr/scripts/DisplayProfile.sh}"
DPM_SETUP_SCRIPT="${DPM_SETUP_SCRIPT:-$config_home/hypr/scripts/DisplayProfileSetup.sh}"
DPM_LAUNCHER="${DPM_LAUNCHER:-rofi}"
DPM_ROFI_CONFIG="${DPM_ROFI_CONFIG:-$config_home/hypr/rofi/config-Monitors.rasi}"
DPM_NWG_DISPLAYS="${DPM_NWG_DISPLAYS:-nwg-displays}"
DPM_JQ="${DPM_JQ:-jq}"
DPM_NOTIFY="${DPM_NOTIFY:-notify-send}"
DPM_STORE_FILE="${DPM_STORE_FILE:-$config_home/hypr/UserConfigs/display-layouts.json}"
DPM_RUNTIME_DIR="${DPM_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}}"
STATE_DIR="$DPM_RUNTIME_DIR/kooldots-display-profiles"
DPM_LOG_FILE="${DPM_LOG_FILE:-$STATE_DIR/menu.log}"

DRY_RUN=0
[[ ${1:-} == "--dry-run" ]] && DRY_RUN=1

# shellcheck source=./lib_display_store.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib_display_store.sh"
DS_JQ="$DPM_JQ"

log() {
  local line
  line="$(date '+%Y-%m-%d %H:%M:%S') [DisplayProfileMenu] $*"
  printf '%s\n' "$line" >&2
  mkdir -p -- "$(dirname -- "$DPM_LOG_FILE")" 2>/dev/null || return 0
  printf '%s\n' "$line" >>"$DPM_LOG_FILE" 2>/dev/null || true
}

notify() {
  command -v "$DPM_NOTIFY" >/dev/null 2>&1 || return 0
  "$DPM_NOTIFY" -a "Display layouts" "$1" "${2:-}" >/dev/null 2>&1 || true
}

# --- rofi ------------------------------------------------------------------
# ask_index <mesg> <prompt> <rows...> -> the chosen index on stdout, or nothing.
ask_index() {
  local mesg=$1 prompt=$2; shift 2
  local -a args=(-i -dmenu -format i -p "$prompt" -mesg "$mesg")
  [[ -r $DPM_ROFI_CONFIG ]] && args+=(-config "$DPM_ROFI_CONFIG")
  printf '%s\n' "$@" | "$DPM_LAUNCHER" "${args[@]}" 2>/dev/null || true
}

# ask_text <prompt> -> free text, the only such input in this system.
ask_text() {
  local prompt=$1
  local -a args=(-dmenu -p "$prompt")
  [[ -r $DPM_ROFI_CONFIG ]] && args+=(-config "$DPM_ROFI_CONFIG")
  printf '' | "$DPM_LAUNCHER" "${args[@]}" 2>/dev/null || true
}

ask_name() {  # prompt -> a validated name, or nothing
  local prompt=$1 name
  name="$(ask_text "$prompt")"
  name="${name%$'\n'}"
  if [[ -z $name ]]; then
    log "no name given; nothing saved"
    return 1
  fi
  if ! ds_name_valid "$name"; then
    log "refusing the name '$name': letters, digits, space, dot, dash and underscore only, 1-32 characters"
    notify "Display layouts" "That name has characters I cannot store. Letters, digits, space . - _ only."
    return 1
  fi
  printf '%s\n' "$name"
}

# --- the monitor set in front of us ----------------------------------------
# Deliberately not NORM/FP: a plain assignment to a name that arrived from the
# environment keeps its export flag, so a generic name here would silently
# overwrite an identically-named variable in every child process.
MON_FILE=""
MON_FP=""
load_monitors() {
  MON_FILE="$("$DPM_PROFILE_SCRIPT" monitors-json 2>/dev/null | tail -n1 || true)"
  if [[ -z $MON_FILE || ! -f $MON_FILE ]]; then
    log "cannot read the monitor list; is Hyprland running?"
    notify "Display layouts" "Cannot read the monitor list"
    return 1
  fi
  MON_FP="$(ds_fingerprint "$MON_FILE")"
  [[ -n $MON_FP ]] || { log "no monitors connected"; notify "Display layouts" "No monitors connected"; return 1; }
}

set_label() {
  ds_store_read "$DPM_STORE_FILE" \
    | "$DS_JQ" -r --arg fp "$MON_FP" '.fingerprints[$fp].label // ""'
}

set_default_name() {
  ds_store_read "$DPM_STORE_FILE" \
    | "$DS_JQ" -r --arg fp "$MON_FP" '.fingerprints[$fp].default // ""'
}

running_name() {
  [[ -f $STATE_DIR/current ]] || return 0
  sed -n '2p' -- "$STATE_DIR/current" 2>/dev/null || true
}

layout_names() { ds_layout_names "$MON_FILE" "$DPM_STORE_FILE"; }

# --- actions ---------------------------------------------------------------
run_controller() {  # the controller's own verbs, always with -- before data
  if [[ $DRY_RUN -eq 1 ]]; then printf 'DRY: DisplayProfile.sh %s\n' "$*"; return 0; fi
  "$DPM_PROFILE_SCRIPT" "$@"
}

arrange_monitors() {
  if ! command -v "$DPM_NWG_DISPLAYS" >/dev/null 2>&1; then
    log "nwg-displays is not installed; install it to arrange monitors by dragging"
    notify "Display layouts" "Install nwg-displays to arrange monitors by dragging"
    return 1
  fi
  if [[ $DRY_RUN -eq 1 ]]; then printf 'DRY: %s -m <discard>\n' "$DPM_NWG_DISPLAYS"; return 0; fi
  mkdir -p -- "$STATE_DIR"
  # nwg-displays always writes a hyprlang monitors.conf, which this Lua config
  # never reads, and from 0.4.3 it also writes a Lua sibling next to it. Point it
  # at a DISCARD path in the state directory - never at
  # UserConfigs/monitors.lua, which this system owns - and keep the path ending
  # in .conf so the sibling is contained here too instead of escaping to
  # ~/.config/hypr/monitors.lua.
  local discard="$STATE_DIR/nwg-monitors.discard.conf"
  local sibling="$STATE_DIR/nwg-monitors.discard.lua"
  rm -f -- "$discard" "$sibling"
  # Pause BEFORE the GUI starts, with our own PID, and only then replace it with
  # the GUI's. nwg applies its arrangement itself (dpms plus `hyprctl reload`),
  # and that reload emits a burst of monitor events: if the watcher saw them it
  # would re-apply the stored layout and silently undo the drag. Writing the
  # pause file after the fork would leave exactly that window open.
  printf '%s\n' "$$" >"$STATE_DIR/pause"
  # 9>&- : never hand a lock descriptor to a GUI that outlives this script.
  "$DPM_NWG_DISPLAYS" -m "$discard" 9>&- &
  local pid=$!
  printf '%s\n' "$pid" >"$STATE_DIR/pause"
  wait "$pid" || true
  rm -f -- "$STATE_DIR/pause"

  # nwg's reload put the STORED layout back on screen, because the Lua config
  # does not read nwg's file. Bridge it: hand that file to the controller, which
  # parses it, applies it through hl.monitor, and writes it to
  # UserConfigs/monitors.lua so it survives. The menu then reopens and offers to
  # save it under a name.
  if [[ -s $discard ]] && grep -q '^[[:space:]]*monitor=' "$discard" 2>/dev/null; then
    log "importing the arrangement nwg-displays wrote"
    "$DPM_PROFILE_SCRIPT" import-nwg "$discard" 9>&- \
      || notify "Display layouts" "Could not apply the arrangement from nwg-displays"
  else
    log "nwg-displays wrote no arrangement; nothing to import"
  fi
  rm -f -- "$discard" "$sibling"
  return 0
}

pick_layout_name() {  # prompt -> a name chosen from the existing layouts
  local prompt=$1
  local -a names=()
  mapfile -t names < <(layout_names)
  (( ${#names[@]} )) || { notify "Display layouts" "No saved layouts for this monitor set"; return 1; }
  local idx
  idx="$(ask_index "Monitor set: $(set_label_or_fp)" "$prompt" "${names[@]}")"
  [[ $idx =~ ^[0-9]+$ ]] || return 1
  (( idx >= 0 && idx < ${#names[@]} )) || return 1
  printf '%s\n' "${names[$idx]}"
}

set_label_or_fp() {
  local l; l="$(set_label)"
  [[ -n $l ]] && { printf '%s\n' "$l"; return 0; }
  printf '%s\n' "$MON_FP"
}

reset_store() {
  local idx bak
  idx="$(ask_index "This deletes every saved layout for every monitor set" \
         "Reset the layout store?" "No, keep them" "Yes, reset the store")"
  [[ $idx == 1 ]] || { log "reset cancelled"; return 0; }
  if [[ $DRY_RUN -eq 1 ]]; then printf 'DRY: reset the layout store\n'; return 0; fi
  # This is the only writer allowed to touch a damaged store, which is exactly
  # the case where the user cannot re-derive what is in it. No backup, no write.
  if [[ -f $DPM_STORE_FILE ]]; then
    if ! bak="$(ds_store_backup "$DPM_STORE_FILE")" || [[ -z ${bak:-} ]]; then
      log "ERROR: could not back the store up; refusing to reset it"
      notify "Display layouts" "Could not back the layout file up, so nothing was reset"
      return 1
    fi
    log "backed the store up to $bak"
  fi
  mkdir -p -- "$(dirname -- "$DPM_STORE_FILE")"
  printf '{"version":1,"fingerprints":{}}\n' >"$DPM_STORE_FILE"
  log "the layout store is empty again"
  notify "Display layouts" "Layout store reset${bak:+ (backup: $(basename -- "$bak"))}"
}

# --- the menu --------------------------------------------------------------
# Built fresh every time it opens: the rows depend on what is saved for the
# monitors currently connected.
build_rows() {
  ROWS=(); ACTIONS=()
  local name dflt running mark
  dflt="$(set_default_name)"
  running="$(running_name)"
  while IFS= read -r name; do
    [[ -n $name ]] || continue
    mark=""
    [[ $name == "$dflt" ]] && mark="  ★"
    [[ $name == "$running" ]] && mark="$mark  ←"
    ROWS+=("$name$mark"); ACTIONS+=("layout:$name")
  done < <(layout_names)

  if (( ${#ROWS[@]} )); then
    ROWS+=("────────────────"); ACTIONS+=("noop")
  fi
  ROWS+=("Automatic");                                        ACTIONS+=("auto")
  ROWS+=("Arrange monitors — drag and drop (nwg-displays)");   ACTIONS+=("arrange")
  ROWS+=("Save current state as…");                           ACTIONS+=("save")
  ROWS+=("Edit parameters (table)");                          ACTIONS+=("table")
  ROWS+=("Set as default…");                                  ACTIONS+=("setdefault")
  ROWS+=("Rename monitor set…");                              ACTIONS+=("label")
  ROWS+=("Delete layout…");                                   ACTIONS+=("delete")
  ROWS+=("Reset layout store…");                              ACTIONS+=("reset")
  ROWS+=("Exit");                                             ACTIONS+=("exit")
}

menu_once() {  # $1: an extra note for the message line
  local note=${1:-} idx action name count
  build_rows
  count="$(ds_count "$MON_FILE")"
  local mesg
  mesg="Monitor set: $(set_label_or_fp) ($count monitors)"
  local running; running="$(running_name)"
  [[ -n $running ]] && mesg="$mesg · running: $running"
  [[ -n $note ]] && mesg="$note · $mesg"

  idx="$(ask_index "$mesg" "Display layout" "${ROWS[@]}")"
  idx="${idx%%[^0-9]*}"
  [[ $idx =~ ^[0-9]+$ ]] || { log "nothing chosen"; return 1; }
  (( idx >= 0 && idx < ${#ACTIONS[@]} )) || { log "choice $idx is out of range"; return 1; }

  action="${ACTIONS[$idx]}"
  case $action in
    noop | exit) return 1 ;;
    layout:*)    run_controller -- "${action#layout:}"; return 1 ;;
    auto)        run_controller auto; return 1 ;;
    table)
      if [[ -x $DPM_SETUP_SCRIPT ]]; then
        [[ $DRY_RUN -eq 1 ]] && { printf 'DRY: %s\n' "$DPM_SETUP_SCRIPT"; return 1; }
        # Hand over the layout that is running, so editing it keeps its primary
        # and its Waybar selection. Starting from a fresh capture instead would
        # silently reset both when the user saved under the same name.
        local running_layout; running_layout="$(running_name)"
        if [[ -n $running_layout && $running_layout != "(auto)" ]] \
           && layout_names | grep -qxF -- "$running_layout"; then
          exec "$DPM_SETUP_SCRIPT" -- "$running_layout"
        fi
        exec "$DPM_SETUP_SCRIPT"
      fi
      notify "Display layouts" "The parameter table is not installed"
      return 1
      ;;
    arrange)
      arrange_monitors || return 1
      # Reopen so the arrangement can be saved: nwg-displays knows nothing
      # about monitor sets, so an unsaved drag is lost on the next replug.
      printf '%s\n' "unsaved arrangement"
      return 0
      ;;
    save)
      name="$(ask_name 'Save the current state as')" || return 1
      run_controller capture -- "$name"
      return 1
      ;;
    setdefault)
      name="$(pick_layout_name 'Make default')" || return 1
      run_controller set-default -- "$name"
      return 1
      ;;
    delete)
      name="$(pick_layout_name 'Delete which layout')" || return 1
      run_controller delete -- "$name"
      return 1
      ;;
    label)
      name="$(ask_name 'Name this monitor set')" || return 1
      run_controller label -- "$name"
      return 1
      ;;
    reset)
      reset_store
      return 1
      ;;
  esac
  return 1
}

main() {
  # Don't stack popups, same as the other rofi menus in these dots.
  if command -v pgrep >/dev/null 2>&1 && pgrep -x rofi >/dev/null 2>&1; then
    pkill -x rofi >/dev/null 2>&1 || true
    sleep 0.1
  fi
  load_monitors || exit 1
  local note=""
  # Loops only where an action asks to be followed by another choice.
  while note="$(menu_once "$note")"; do :; done
  exit 0
}

main "$@"
