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
# also source, so all three agree on the mapping and there is one place to
# change it. This script is the manual entry point: it renders the templates
# but does not reload anything. For the full flow - render, reload Waybar and
# cava, re-apply the Hyprland borders, re-apply Rainbow Borders - run
# WallustSwww.sh, which does all of that and uses whichever palette source is
# configured.
#
# Usage: ButterpalWallust.sh <image> [options]
#
#   --source butterpal|wallust   Write the palette-source state file and exit.
#                                Without it the source is auto-detected.
#   --roles accent|ansi          How butterpal's colours fill the dots' accent
#                                slots. Default: accent.
#   --dry-run                    Print the mapping and the palette, render
#                                nothing.
#
# Source resolution order, and the role mapping itself, are documented in
# WallustConfig.sh.

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

roles="${KOOLDOTS_PALETTE_ROLES:-accent}"
dry_run=0
image=""
set_source=""

usage() {
  sed -n '/^# Usage:/,/^# WallustConfig.sh/p' "$0" | sed 's/^# \{0,1\}//' | sed '$d'
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
  --source)
    [ "$#" -ge 2 ] || usage
    set_source="$2"
    shift 2
    ;;
  --roles)
    [ "$#" -ge 2 ] || usage
    roles="$2"
    KOOLDOTS_PALETTE_ROLES="$2"
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

case "$roles" in
ansi | accent) ;;
*)
  printf 'ButterpalWallust.sh: --roles must be ansi or accent, got: %s\n' "$roles" >&2
  exit 2
  ;;
esac

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
  mapfile -t pal < <(butterpal "$image")
  if [ "${#pal[@]}" -ne 24 ]; then
    printf 'ButterpalWallust.sh: expected 24 colours from butterpal, got %d\n' "${#pal[@]}" >&2
    exit 1
  fi
  printf 'source=%s roles=%s\nimage=%s\n\n' "$palette_source" "$roles" "$image"
  printf '%-10s %s\n' \
    background "${pal[0]}" \
    second-bg "${pal[1]}" \
    text "${pal[2]}" \
    border "${pal[3]}" \
    primary "${pal[4]}" \
    secondary "${pal[5]}" \
    alert "${pal[6]}" \
    disabled "${pal[7]}"
  printf '\n'
  if ! butterpal_palette_from_image "$image"; then
    printf 'ButterpalWallust.sh: no palette produced\n' >&2
    exit 1
  fi
  cat "$butterpal_palette_json"
  exit 0
fi

if ! butterpal_palette_from_image "$image"; then
  printf 'ButterpalWallust.sh: butterpal produced no palette for %s\n' "$image" >&2
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

printf 'ButterpalWallust.sh: rendered wallust templates from %s (roles=%s)\n' "$image" "$roles"
