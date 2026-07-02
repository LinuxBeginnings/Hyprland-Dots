#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Ubuntu-based workaround: start portals manually before waybar.

set -euo pipefail

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${ID:-}" == "ubuntu" \
        || "${ID:-}" == "linuxmint" \
        || "${ID:-}" == "zorin" \
        || "${ID:-}" == "rhino" \
        || "${ID_LIKE:-}" == *ubuntu* ]]; then
    if [[ -x "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/PortalHyprland.sh" ]]; then
      "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/PortalHyprland.sh"
    fi
  fi
fi
