#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Cycle windows in a layout-aware way.

set -euo pipefail

action="${1:-next}"

if [[ "$action" != "next" && "$action" != "prev" ]]; then
  echo "Usage: $(basename "$0") [next|prev]" >&2
  exit 1
fi

layout="$(hyprctl -j getoption general:layout | jq -r '.str')"

if [[ "$layout" == "master" || "$layout" == "monocle" ]]; then
  hyprctl dispatch layoutmsg "cycle${action}"
else
  if [[ "$action" == "next" ]]; then
    hyprctl dispatch cyclenext
  else
    hyprctl dispatch cyclenext prev
  fi
fi
