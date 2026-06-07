#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Wallust version compatibility helpers
#
# Purpose:
# - Wallust v3 reads ~/.config/wallust/wallust.toml (this repo ships a v3 config)
# - Wallust v4 alpha uses a different config schema; users frequently install it
#   via wallust-git, which will fail to parse the v3 config.
#
# This file detects Wallust major version and sets arrays used by scripts:
# - wallust_args: args to pass to wallust for wallpaper-derived palette generation
# - wallust_kitty_args: args to pass to wallust for kitty-only palette generation

wallust_args=()
wallust_kitty_args=()

wallust_prepare_args() {
  wallust_args=()
  wallust_kitty_args=()

  command -v wallust >/dev/null 2>&1 || return 0

  local version major
  version=$(wallust --version 2>/dev/null | awk '{print $2}')
  major=${version%%.*}

  # Wallust v4 supports -C/--config-file.
  if [ -n "$major" ] && [ "$major" -ge 4 ]; then
    local v4_cfg="$HOME/.config/wallust/wallust-v4.toml"
    local v4_kitty_cfg="$HOME/.config/wallust/wallust-kitty-v4.toml"

    if [ -f "$v4_cfg" ]; then
      wallust_args=(-C "$v4_cfg")
    fi
    if [ -f "$v4_kitty_cfg" ]; then
      wallust_kitty_args=(-C "$v4_kitty_cfg")
    fi
  fi
}

wallust_prepare_args
