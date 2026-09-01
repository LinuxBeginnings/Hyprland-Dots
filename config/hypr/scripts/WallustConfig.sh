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
# - Wallust v3 reads ${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallust/wallust.toml (this repo ships a v3 config)
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
  local wallust_cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallust"
  local legacy_wallust_cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/wallust"
  local v3_cfg=""
  local v3_kitty_cfg=""
  local v4_cfg=""
  local v4_kitty_cfg=""
  local version major
  version=$(wallust --version 2>/dev/null | awk '{print $2}')
  major=$(printf '%s' "$version" | sed -E 's/^[^0-9]*([0-9]+).*$/\1/' 2>/dev/null || true)
  if [ -f "$wallust_cfg_dir/wallust.toml" ]; then
    v3_cfg="$wallust_cfg_dir/wallust.toml"
  elif [ -f "$legacy_wallust_cfg_dir/wallust.toml" ]; then
    v3_cfg="$legacy_wallust_cfg_dir/wallust.toml"
  fi

  if [ -f "$wallust_cfg_dir/wallust-kitty.toml" ]; then
    v3_kitty_cfg="$wallust_cfg_dir/wallust-kitty.toml"
  elif [ -f "$legacy_wallust_cfg_dir/wallust-kitty.toml" ]; then
    v3_kitty_cfg="$legacy_wallust_cfg_dir/wallust-kitty.toml"
  fi

  if [ -f "$wallust_cfg_dir/wallust-v4.toml" ]; then
    v4_cfg="$wallust_cfg_dir/wallust-v4.toml"
  elif [ -f "$legacy_wallust_cfg_dir/wallust-v4.toml" ]; then
    v4_cfg="$legacy_wallust_cfg_dir/wallust-v4.toml"
  fi

  if [ -f "$wallust_cfg_dir/wallust-kitty-v4.toml" ]; then
    v4_kitty_cfg="$wallust_cfg_dir/wallust-kitty-v4.toml"
  elif [ -f "$legacy_wallust_cfg_dir/wallust-kitty-v4.toml" ]; then
    v4_kitty_cfg="$legacy_wallust_cfg_dir/wallust-kitty-v4.toml"
  fi

  # Always pass an explicit config path after namespace migration.
  # v4 prefers v4 configs; v3 uses wallust.toml.
  if [[ "$major" =~ ^[0-9]+$ ]] && [ "$major" -ge 4 ]; then
    if [ -n "$v4_cfg" ]; then
      wallust_args=(-d "$wallust_cfg_dir" -C "$v4_cfg")
    fi
    if [ -n "$v4_kitty_cfg" ]; then
      wallust_kitty_args=(-d "$wallust_cfg_dir" -C "$v4_kitty_cfg")
    fi
  else
    if [ -n "$v3_cfg" ]; then
      wallust_args=(-d "$wallust_cfg_dir" -C "$v3_cfg")
    fi
    if [ -n "$v3_kitty_cfg" ]; then
      wallust_kitty_args=(-d "$wallust_cfg_dir" -C "$v3_kitty_cfg")
    fi
  fi

  # Last-resort fallback: if version parsing failed, still prefer any migrated config.
  if [ "${#wallust_args[@]}" -eq 0 ]; then
    if [ -n "$v3_cfg" ]; then
      wallust_args=(-d "$wallust_cfg_dir" -C "$v3_cfg")
    elif [ -n "$v4_cfg" ]; then
      wallust_args=(-d "$wallust_cfg_dir" -C "$v4_cfg")
    fi
  fi
  if [ "${#wallust_kitty_args[@]}" -eq 0 ]; then
    if [ -n "$v3_kitty_cfg" ]; then
      wallust_kitty_args=(-d "$wallust_cfg_dir" -C "$v3_kitty_cfg")
    elif [ -n "$v4_kitty_cfg" ]; then
      wallust_kitty_args=(-d "$wallust_cfg_dir" -C "$v4_kitty_cfg")
    fi
  fi
}

wallust_prepare_args
