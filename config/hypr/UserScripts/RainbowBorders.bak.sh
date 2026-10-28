#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Smooth border cycling effect using Wallust palette or full rainbow
#
# Disabled by default as RainbowBorders.bak.sh.
# Enable / choose mode via Quick Settings (SUPER SHIFT + E → Rainbow Borders Mode).
# That renames this file to RainbowBorders.sh.
#
# Under Hyprland Lua config mode the border is written with hyprctl eval:
#   hyprctl eval 'hl.config({ general = { col = { active_border = { colors = {...}, angle = N } } } })'
# Hyprland 0.57 removed the legacy "keyword" socket command, and hyprctl still
# exits 0 while answering "unknown request", so eval is the primary path and
# keyword is only a fallback for builds that have no eval command.
#
# The gradient angle is a diagonal on purpose. This is a one-shot write, so an
# axis-aligned angle leaves the two edges parallel to it a single flat colour:
# at 270deg the long top and bottom edges were one colour each, which reads as
# a solid border rather than a rainbow. A diagonal puts part of the spectrum
# on all four edges. 0 and 90 are the flat-edge cases, 45 and 135 the diagonals.

# Possible values: "wallust_random", "rainbow", "gradient_flow"
EFFECT_TYPE="gradient_flow"

# Gradient angle in degrees. Default 45 (diagonal).
RB_ANGLE="${RB_ANGLE:-45}"

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

# ---------- RANDOM WALLUST COLORS ----------
function wallust_random() {
  if ((${#WALLUST_COLORS[@]} == 0)); then
    random_hex
    return
  fi
  echo "${WALLUST_COLORS[RANDOM % ${#WALLUST_COLORS[@]}]}"
}

# ---------- RAINBOW COLORS ----------
# Fixed spectrum so "Original Rainbow" is visibly multi-hue (not random pastels).
RAINBOW_PALETTE=(
  "0xffff0000" "0xffff8000" "0xffffff00" "0xff80ff00" "0xff00ff00"
  "0xff00ff80" "0xff00ffff" "0xff0080ff" "0xff0000ff" "0xff8000ff"
)
function random_hex() {
  # Keep name for compatibility; prefer palette entry by index when available.
  if ((${#RAINBOW_PALETTE[@]} > 0)); then
    echo "${RAINBOW_PALETTE[RANDOM % ${#RAINBOW_PALETTE[@]}]}"
    return
  fi
  if command -v openssl >/dev/null 2>&1; then
    echo "0xff$(openssl rand -hex 3)"
  else
    printf '0xff%02x%02x%02x\n' $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256))
  fi
}
function rainbow_color() {
  local idx="${1:-0}"
  if ((${#RAINBOW_PALETTE[@]} > 0)); then
    echo "${RAINBOW_PALETTE[idx % ${#RAINBOW_PALETTE[@]}]}"
    return
  fi
  random_hex
}

# ---------- FLOW MODE ----------
BASE_COLOR="${WALLUST_COLORS[10]}"
GRAD1_COLOR="${WALLUST_COLORS[14]}"
GRAD2_COLOR="${WALLUST_COLORS[13]}"
GLOW_COLOR="${WALLUST_COLORS[15]}"

MAX_POS=10
GLOW_POS=0

function gradient_flow_color() {
  local pos=$1
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

  if ((pos == MAX_POS - 1)); then
    GLOW_POS=$(((GLOW_POS + 1) % MAX_POS))
  fi
}

# ---------- Main function ----------
function get_color() {
  if [[ "$EFFECT_TYPE" == "wallust_random" && ${#WALLUST_COLORS[@]} -gt 0 ]]; then
    wallust_random
  elif [[ "$EFFECT_TYPE" == "gradient_flow" && ${#WALLUST_COLORS[@]} -ge 16 ]]; then
    gradient_flow_color "$1"
  elif [[ "$EFFECT_TYPE" == "rainbow" ]]; then
    rainbow_color "$1"
  else
    random_hex
  fi
}

# Set a gradient border option through Hyprland's Lua state.
# Usage: set_gradient_border general:col.active_border color0 color1 ... [angledeg]
set_gradient_border() {
  local option="$1"
  shift
  local angle="$RB_ANGLE"
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

# border effect for ACTIVE window
set_gradient_border general:col.active_border \
  "$(get_color 0)" "$(get_color 1)" "$(get_color 2)" "$(get_color 3)" "$(get_color 4)" \
  "$(get_color 5)" "$(get_color 6)" "$(get_color 7)" "$(get_color 8)" "$(get_color 9)" \
  "${RB_ANGLE}deg"

# border effect for INACTIVE windows (optional)
# set_gradient_border general:col.inactive_border \
#   "$(get_color 0)" "$(get_color 1)" "$(get_color 2)" "$(get_color 3)" "$(get_color 4)" \
#   "$(get_color 5)" "$(get_color 6)" "$(get_color 7)" "$(get_color 8)" "$(get_color 9)" \
#   "${RB_ANGLE}deg"
