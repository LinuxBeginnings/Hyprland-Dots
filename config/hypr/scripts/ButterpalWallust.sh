#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Generate the wallust palette from butterpal instead of wallust's own
# extraction.
#
# The palette logic lives in WallustConfig.sh, which WallustSwww.sh and copy.sh
# also source, so all three agree and there is one place to change it. This
# script is the manual entry point: it renders the templates but does not
# reload anything. For the full flow - render, reload Waybar and cava, re-apply
# the Hyprland borders, re-apply Rainbow Borders - run WallustSwww.sh, which
# does all of that and uses whichever palette source is configured.
#
# Usage: ButterpalWallust.sh <image> [options]
#
#   --source butterpal|wallust   Write the palette-source state file and exit.
#                                Without it the source is auto-detected.
#   --dry-run                    Print the scheme butterpal produced, render
#                                nothing.
#
# Source resolution order is documented in WallustConfig.sh.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
wallust_config="$script_dir/WallustConfig.sh"
if [ ! -f "$wallust_config" ]; then
  wallust_config="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/WallustConfig.sh"
fi
if [ ! -f "$wallust_config" ]; then
  printf 'ButterpalWallust.sh: WallustConfig.sh not found next to this script or in %s\n' \
    "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts" >&2
  exit 1
fi
# shellcheck source=/dev/null
. "$wallust_config"

dry_run=0
image=""
set_source=""

usage() {
  sed -n '/^# Usage:/,/^# Source resolution/p' "$0" | sed 's/^# \{0,1\}//' | sed '$d'
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
  --source)
    [ "$#" -ge 2 ] || usage
    set_source="$2"
    shift 2
    ;;
  --dry-run)
    dry_run=1
    shift
    ;;
  -h | --help)
    usage
    ;;
  -*)
    printf 'ButterpalWallust.sh: unknown option: %s\n' "$1" >&2
    usage
    ;;
  *)
    image="$1"
    shift
    ;;
  esac
done

# --source writes the state file the resolver reads, then stops. This is the
# switch between butterpal and wallust's own extraction.
if [ -n "$set_source" ]; then
  case "$set_source" in
  butterpal | wallust) ;;
  *)
    printf 'ButterpalWallust.sh: --source must be butterpal or wallust, got: %s\n' "$set_source" >&2
    exit 2
    ;;
  esac
  if [ "$set_source" = "butterpal" ] && ! command -v butterpal >/dev/null 2>&1; then
    printf 'ButterpalWallust.sh: butterpal is not installed; it would fall back to wallust.\n' >&2
  fi
  state_file="$(wallust_palette_source_file)"
  mkdir -p "$(dirname "$state_file")"
  printf '%s\n' "$set_source" >"$state_file"
  printf 'Palette source set to %s\n  %s\n' "$set_source" "$state_file"
  exit 0
fi

if [ -z "$image" ]; then
  printf 'ButterpalWallust.sh: no image given\n' >&2
  usage
fi
if [ ! -f "$image" ]; then
  printf 'ButterpalWallust.sh: cannot read image: %s\n' "$image" >&2
  exit 1
fi
command -v butterpal >/dev/null 2>&1 || {
  printf 'ButterpalWallust.sh: butterpal not found in PATH\n' >&2
  exit 1
}

if [ "$dry_run" -eq 1 ]; then
  printf 'source=%s\nimage=%s\n\n' "$palette_source" "$image"
  if ! butterpal_palette_from_image "$image"; then
    printf 'ButterpalWallust.sh: butterpal produced no scheme for %s\n' "$image" >&2
    printf 'Its formats are PNG, JPEG, BMP and GIF; anything else falls back\n' >&2
    printf 'to `wallust run` in the real flow.\n' >&2
    exit 1
  fi
  # The accent the dots read is the scheme's cursor, not its ANSI color12.
  printf 'accent (cursor) %s\n' \
    "$(sed -n 's/.*"cursor":"\(#[0-9a-fA-F]*\)".*/\1/p' "$butterpal_palette_json" | head -n1)"
  printf 'background      %s\n' \
    "$(sed -n 's/.*"background":"\(#[0-9a-fA-F]*\)".*/\1/p' "$butterpal_palette_json" | head -n1)"
  printf 'foreground      %s\n\n' \
    "$(sed -n 's/.*"foreground":"\(#[0-9a-fA-F]*\)".*/\1/p' "$butterpal_palette_json" | head -n1)"
  cat "$butterpal_palette_json"
  exit 0
fi

if ! butterpal_palette_from_image "$image"; then
  printf 'ButterpalWallust.sh: butterpal produced no scheme for %s\n' "$image" >&2
  exit 1
fi

if [ "${#wallust_args[@]}" -eq 0 ]; then
  printf 'ButterpalWallust.sh: no wallust config found; is WallustConfig.sh installed?\n' >&2
  exit 1
fi

wallust_cs_from_palette "${wallust_args[@]}"

# The kitty palette is a separate wallust config with its own target.
if [ "${#wallust_kitty_args[@]}" -gt 0 ]; then
  wallust_cs_from_palette "${wallust_kitty_args[@]}"
fi

printf 'ButterpalWallust.sh: rendered wallust templates from %s\n' "$image"
