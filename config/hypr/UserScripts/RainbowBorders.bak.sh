#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Animated border cycling effect using the Wallust palette or a full rainbow.
#
# Disabled by default as RainbowBorders.bak.sh.
# Enable / choose mode via Quick Settings (SUPER SHIFT + E → Rainbow Borders Mode).
# That renames this file to RainbowBorders.sh.
#
# Effects, chosen by EFFECT_TYPE (written by the Quick Settings menu):
#   wallust_random   ten consecutive wallpaper-palette colours, window slides
#   rainbow          the fixed ten-hue spectrum, angle rotates
#   gradient_flow    a glow band travelling over one base palette colour
#
# Under Hyprland Lua config mode the border is written with hyprctl eval:
#   hyprctl eval 'hl.config({ general = { col = { active_border = { colors = {...}, angle = N } } } })'
# Hyprland 0.57 removed the legacy "keyword" socket command, and hyprctl still
# exits 0 while answering "unknown request", so eval is the primary path and
# keyword is only a fallback for builds that have no eval command.
#
# The gradient angle is a diagonal on purpose. An axis-aligned angle leaves the
# two edges parallel to it a single flat colour: at 270deg the long top and
# bottom edges were one colour each, which reads as a solid border rather than a
# rainbow. A diagonal puts part of the spectrum on all four edges.
#
# Why this loops
#   The frame state - palette offset, glow position, angle - lives in this
#   process, so the effect only animates while the loop is running. As a
#   one-shot script it could not: gradient_flow advanced GLOW_POS only at the
#   end of a run, and every run was a fresh process starting from position 0, so
#   the glow was permanently parked at the same stop and half the border was one
#   colour. Wallust Color picked each of its ten stops independently at random,
#   which scrambled the order and averaged out to a mid-tone on a thin border.
#
# Environment overrides:
#   RB_INTERVAL   Float seconds between frames   (default 1.0)
#   RB_STEP_DEG   Degrees of rotation per frame  (default 10)
#   RB_ANGLE      Starting gradient angle        (default 45)
#   RB_RESTORE    1 to restore the border on exit (loop mode; default 1)
#   RB_LOCKFILE   PID lock path (default /tmp/hypr-rainbowborders-classic.lock)
#   RB_ONCE       1 to write one frame and exit  (same as --once)

set -u

# Possible values: "wallust_random", "rainbow", "gradient_flow"
EFFECT_TYPE="gradient_flow"

RB_INTERVAL="${RB_INTERVAL:-1.0}"
RB_STEP_DEG="${RB_STEP_DEG:-10}"
RB_ANGLE="${RB_ANGLE:-45}"
RB_RESTORE="${RB_RESTORE:-1}"
RB_TARGET="${RB_TARGET:-general:col.active_border}"
RB_LOCKFILE="${RB_LOCKFILE:-/tmp/hypr-rainbowborders-classic.lock}"
RB_ONCE="${RB_ONCE:-0}"

usage() {
  cat <<'EOF'
Usage: RainbowBorders.sh [options]

Options:
  -h, --help                  Show this help and exit
  --once, --run-once, -1      Write one frame and exit (no animation)

Environment overrides:
  RB_INTERVAL   Float seconds between frames   (default 1.0)
  RB_STEP_DEG   Degrees of rotation per frame  (default 10)
  RB_ANGLE      Starting gradient angle        (default 45)
  RB_RESTORE    1 to restore the border on exit (loop mode; default 1)
  RB_LOCKFILE   PID lock path (default /tmp/hypr-rainbowborders-classic.lock)
  RB_ONCE       1 for one-shot mode (same as --once)

Effects are selected by EFFECT_TYPE, which the Quick Settings menu rewrites.
EOF
}

is_float() { [[ "$1" =~ ^[0-9]+(\.[0-9]+)?$|^\.[0-9]+$ ]]; }

is_int() { [[ "$1" =~ ^[0-9]+$ ]]; }

while (( $# )); do
  case "$1" in
  -h | --help)
    usage
    exit 0
    ;;
  --once | --run-once | -1) RB_ONCE=1 ;;
  *)
    printf '[RainbowBorders] unknown option: %s\n' "$1" >&2
    usage >&2
    exit 2
    ;;
  esac
  shift
done

if ! is_float "$RB_INTERVAL"; then
  printf '[RainbowBorders] WARN: RB_INTERVAL=%s invalid; using 1.0\n' "$RB_INTERVAL" >&2
  RB_INTERVAL="1.0"
fi
if ! is_int "$RB_STEP_DEG"; then
  printf '[RainbowBorders] WARN: RB_STEP_DEG=%s invalid; using 10\n' "$RB_STEP_DEG" >&2
  RB_STEP_DEG="10"
fi
if ! is_int "$RB_ANGLE"; then
  printf '[RainbowBorders] WARN: RB_ANGLE=%s invalid; using 45\n' "$RB_ANGLE" >&2
  RB_ANGLE="45"
fi

WALLUST_COLORS_SOURCE="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallust/wallust-hyprland.conf"

WALLUST_COLORS=()

# ---------- LOAD WALLUST COLORS ----------
if [[ "$EFFECT_TYPE" == "wallust_random" || "$EFFECT_TYPE" == "gradient_flow" ]]; then
  # Normalize whatever the palette file holds to 0xffRRGGBB. Wallust itself
  # writes `rgb(RRGGBB)` - six hex digits, no commas - which is the form
  # lua/user_decorations_helper.lua parses. A parser that only knew 0x...,
  # #RRGGBB and rgb(r,g,b) matched nothing here, so every wallust mode fell
  # through to the plain rainbow below and looked identical to Original Rainbow.
  mapfile -t WALLUST_COLORS < <(
    grep -E '^\$color[0-9]+' "$WALLUST_COLORS_SOURCE" | awk '
        function hex2(s){ return (length(s)==6 ? "0xff"s : ""); }
        function rgb2(r,g,b){ return sprintf("0xff%02x%02x%02x", r, g, b); }
        {
            if (match($0, /0x([0-9a-fA-F]{8})/, m)) { print "0x" m[1]; next }
            if (match($0, /#([0-9a-fA-F]{6})/, m))  { print hex2(m[1]); next }
            if (match($0, /rgb\(([0-9]+),[ ]*([0-9]+),[ ]*([0-9]+)\)/, m)) {
                print rgb2(m[1], m[2], m[3]); next
            }
            # rgb(RRGGBB) / rgba(RRGGBBAA): bare hex, no commas, no marker.
            if (match($0, /rgba?\(([0-9a-fA-F]{6})[0-9a-fA-F]{0,2}\)/, m)) {
                print "0xff" m[1]; next
            }
        }'
  )

  if ((${#WALLUST_COLORS[@]} == 0)); then
    # Still nothing: keep the old fallback rather than hand an empty gradient
    # to Hyprland, which rejects it and leaves the border unchanged.
    EFFECT_TYPE="rainbow"
  fi
fi

# ---------- RAINBOW COLORS ----------
# Fixed spectrum so "Original Rainbow" is visibly multi-hue (not random pastels).
RAINBOW_PALETTE=(
  "0xffff0000" "0xffff8000" "0xffffff00" "0xff80ff00" "0xff00ff00"
  "0xff00ff80" "0xff00ffff" "0xff0080ff" "0xff0000ff" "0xff8000ff"
)

function rainbow_color() {
  local idx="${1:-0}"
  echo "${RAINBOW_PALETTE[idx % ${#RAINBOW_PALETTE[@]}]}"
}

# ---------- WALLUST COLORS ----------
# Ten consecutive palette entries, starting at WALLUST_OFFSET. advance_state
# slides that window one stop per frame, so the border cycles through the
# wallpaper's own colours in palette order.
function wallust_color() {
  local pos="${1:-0}" n="${#WALLUST_COLORS[@]}"
  if ((n == 0)); then
    rainbow_color "$pos"
    return
  fi
  echo "${WALLUST_COLORS[(WALLUST_OFFSET + pos) % n]}"
}

# ---------- FLOW MODE ----------
# Defaulted rather than read bare: under `set -u` an index past the end of the
# palette is an unbound-variable error, and `rainbow` never loads the palette.
BASE_COLOR="${WALLUST_COLORS[10]:-}"
GRAD1_COLOR="${WALLUST_COLORS[14]:-}"
GRAD2_COLOR="${WALLUST_COLORS[13]:-}"
GLOW_COLOR="${WALLUST_COLORS[15]:-}"

MAX_POS=10

# One base colour with a glow band straddling GLOW_POS. advance_state moves
# GLOW_POS every frame, which is what makes the glow travel.
function gradient_flow_color() {
  local pos="${1:-0}"
  local d=$((pos - GLOW_POS))

  # wrap distance (-9..9)
  if ((d > MAX_POS / 2)); then d=$((d - MAX_POS)); fi
  if ((d < -MAX_POS / 2)); then d=$((d + MAX_POS)); fi

  case "${d#-}" in
  0) echo "$GLOW_COLOR" ;;
  1) echo "$GRAD1_COLOR" ;;
  2) echo "$GRAD2_COLOR" ;;
  *) echo "$BASE_COLOR" ;;
  esac
}

# ---------- FRAME ----------
# The animation state. It is advanced by advance_state in this shell and never
# inside a command substitution: a $(...) subshell gets a copy of these
# variables, so an advance made in there would be thrown away.
BORDER_COLORS=()
WALLUST_OFFSET=0
GLOW_POS=0
ANGLE=$((RB_ANGLE % 360))

function color_at() {
  case "$EFFECT_TYPE" in
  wallust_random)
    if ((${#WALLUST_COLORS[@]} > 0)); then wallust_color "$1"; else rainbow_color "$1"; fi
    ;;
  gradient_flow)
    # The flow colours index up to color15, so a short palette falls back to the
    # rainbow rather than writing an empty stop.
    if ((${#WALLUST_COLORS[@]} >= 16)); then gradient_flow_color "$1"; else rainbow_color "$1"; fi
    ;;
  *) rainbow_color "$1" ;;
  esac
}

function frame_colors() {
  local i
  BORDER_COLORS=()
  for i in 0 1 2 3 4 5 6 7 8 9; do
    BORDER_COLORS+=("$(color_at "$i")")
  done
}

function advance_state() {
  local n="${#WALLUST_COLORS[@]}"
  case "$EFFECT_TYPE" in
  wallust_random)
    if ((n > 0)); then
      WALLUST_OFFSET=$(((WALLUST_OFFSET + 1) % n))
    fi
    ;;
  gradient_flow)
    GLOW_POS=$(((GLOW_POS + 1) % MAX_POS))
    ;;
  esac
  ANGLE=$(((ANGLE + RB_STEP_DEG) % 360))
}

# Set a gradient border option through Hyprland's Lua state.
# Usage: set_gradient_border general:col.active_border color0 color1 ... [angledeg]
set_gradient_border() {
  local option="$1"
  shift
  local angle="$ANGLE"
  local -a colors=()
  local arg c lua_colors expr out rc kw_out kw_rc

  for arg in "$@"; do
    if [[ "$arg" =~ ^([0-9]+)deg$ ]]; then
      angle="${BASH_REMATCH[1]}"
    else
      colors+=("$arg")
    fi
  done

  ((${#colors[@]} > 0)) || return 1

  lua_colors=""
  for c in "${colors[@]}"; do
    [[ -n "$lua_colors" ]] && lua_colors+=", "
    lua_colors+="\"${c}\""
  done

  case "$option" in
  general:col.active_border)
    expr="hl.config({ general = { col = { active_border = { colors = { ${lua_colors} }, angle = ${angle} } } } })"
    ;;
  general:col.inactive_border)
    expr="hl.config({ general = { col = { inactive_border = { colors = { ${lua_colors} }, angle = ${angle} } } } })"
    ;;
  *)
    printf '[RainbowBorders] unsupported option: %s\n' "$option" >&2
    return 1
    ;;
  esac

  # Lua config mode. eval answers exactly "ok" on success, so an unregistered
  # command ("unknown request", still exit 0) is not mistaken for a write.
  out="$(hyprctl eval "$expr" 2>&1)"
  rc=$?
  if [[ $rc -eq 0 && "$out" == "ok" ]]; then
    return 0
  fi

  # Legacy conf mode, for Hyprland builds without the eval command.
  kw_out="$(hyprctl keyword "$option" "${colors[@]}" "${angle}deg" 2>&1)"
  kw_rc=$?
  if [[ $kw_rc -eq 0 && "$kw_out" != *"unknown request"* && "$kw_out" != *"non-legacy parsers"* && "$kw_out" != *"Use eval"* && "$kw_out" != *"error"* && "$kw_out" != *"invalid"* ]]; then
    return 0
  fi

  printf '[RainbowBorders] failed to set %s\n' "$option" >&2
  printf '[RainbowBorders] eval error: %s\n' "$out" >&2
  printf '[RainbowBorders] keyword error: %s\n' "$kw_out" >&2
  return 1
}

# ---------- single instance ----------
# One loop owns the border. The Quick Settings menu and
# scripts/RainbowBordersStartup.sh stop the running loop before starting a new
# one, which is what lets an effect change take hold.
# Only remove the lock if it is still ours. A predecessor that is slow to
# finish runs its EXIT trap after the replacement has already written its own
# pid, and an unconditional rm deleted the live loop's lock - which left a
# stale loop nobody could stop by pid.
cleanup_lock() {
  [[ -f "$RB_LOCKFILE" ]] || return 0
  local owner
  owner="$(cat "$RB_LOCKFILE" 2>/dev/null || true)"
  if [[ "$owner" == "$$" ]]; then
    rm -f "$RB_LOCKFILE"
  fi
}

if [[ "$RB_ONCE" != "1" ]]; then
  if [[ -f "$RB_LOCKFILE" ]]; then
    oldpid="$(cat "$RB_LOCKFILE" 2>/dev/null || true)"
    if [[ -n "${oldpid:-}" ]] && kill -0 "$oldpid" 2>/dev/null; then
      printf '[RainbowBorders] another instance is running (pid=%s); exiting\n' "$oldpid" >&2
      exit 0
    fi
    rm -f "$RB_LOCKFILE" || true
  fi
  if ! printf '%d' "$$" >"$RB_LOCKFILE" 2>/dev/null; then
    printf '[RainbowBorders] cannot write lockfile %s\n' "$RB_LOCKFILE" >&2
    exit 1
  fi
fi

# ---------- previous border ----------
PREV_VALUE=""
if [[ "$RB_RESTORE" == "1" && "$RB_ONCE" != "1" ]]; then
  # 0.57 prints "gradient data: <c1> <c2> ... <N>deg" with bare hex values
  # (no 0x prefix) and a separate "set:" line. Older builds printed
  # "str:" / "string:" / "value:" lines instead.
  PREV_VALUE="$(hyprctl getoption "$RB_TARGET" 2>/dev/null \
    | sed -n 's/^.*gradient data:[[:space:]]*//p' \
    | head -n1)"
  if [[ -z "$PREV_VALUE" ]]; then
    PREV_VALUE="$(hyprctl getoption "$RB_TARGET" 2>/dev/null \
      | sed -n 's/^.*str:[[:space:]]\+//p; s/^.*string:[[:space:]]\+//p; s/^.*value:[[:space:]]\+//p' \
      | tail -n1)"
  fi
  # getoption prints bare hex; the config parser needs 0x-prefixed values.
  PREV_VALUE="$(printf '%s' "$PREV_VALUE" \
    | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^[0-9a-fA-F]{6,8}$/) $i = "0x" $i; print }')"
fi

restore_previous() {
  if [[ "$RB_RESTORE" == "1" && -n "${PREV_VALUE:-}" ]]; then
    # shellcheck disable=SC2086 # PREV_VALUE is a colour list plus "<N>deg"
    set_gradient_border "$RB_TARGET" $PREV_VALUE >/dev/null 2>&1 || true
  fi
}

# A signal restores the previous border and then stops the loop. Without the
# exit the trap would only restore, and the loop would overwrite it on the next
# frame while the process stayed alive after SIGTERM.
on_signal() {
  restore_previous
  cleanup_lock
  exit 0
}

if [[ "$RB_ONCE" != "1" ]]; then
  trap on_signal INT TERM
  trap cleanup_lock EXIT
fi

# ---------- main ----------
if [[ "$RB_ONCE" == "1" ]]; then
  # One frame, no restore: a one-shot write is meant to persist.
  frame_colors
  set_gradient_border "$RB_TARGET" "${BORDER_COLORS[@]}" "${ANGLE}deg" || \
    printf '[RainbowBorders] one-shot write failed\n' >&2
  exit 0
fi

# Prime the first frame so the effect appears without waiting one interval.
frame_colors
set_gradient_border "$RB_TARGET" "${BORDER_COLORS[@]}" "${ANGLE}deg" >/dev/null 2>&1 || true

while :; do
  advance_state
  frame_colors
  set_gradient_border "$RB_TARGET" "${BORDER_COLORS[@]}" "${ANGLE}deg" >/dev/null 2>&1 || true
  sleep "$RB_INTERVAL"
done
