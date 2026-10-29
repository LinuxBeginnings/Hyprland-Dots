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
#
# It also resolves which tool extracts the colours. butterpal and wallust both
# turn a wallpaper into a palette; only wallust renders templates. So
# butterpal's colours are written in wallust's cache format and fed back
# through `wallust cs`, which keeps every template and target working and makes
# the two sources interchangeable. See wallust_resolve_palette_source.
# - palette_source: "butterpal" or "wallust"
# - butterpal_palette_json: path to the generated palette, once one exists

wallust_args=()
wallust_kitty_args=()
palette_source=""
butterpal_palette_json=""
wallust_templates_dir=""

wallust_prepare_args() {
  wallust_args=()
  wallust_kitty_args=()

  command -v wallust >/dev/null 2>&1 || return 0
  local wallust_cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallust"
  local legacy_wallust_cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/wallust"
  # Global: the kitty pass reuses this when it has to build its own args.
  wallust_templates_dir="$wallust_cfg_dir/templates"
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
      wallust_args=(--templates-dir "$wallust_templates_dir" -C "$v4_cfg")
    fi
    if [ -n "$v4_kitty_cfg" ]; then
      wallust_kitty_args=(--templates-dir "$wallust_templates_dir" -C "$v4_kitty_cfg")
    fi
  else
    if [ -n "$v3_cfg" ]; then
      wallust_args=(--templates-dir "$wallust_templates_dir" -C "$v3_cfg")
    fi
    if [ -n "$v3_kitty_cfg" ]; then
      wallust_kitty_args=(--templates-dir "$wallust_templates_dir" -C "$v3_kitty_cfg")
    fi
  fi

  # Last-resort fallback: if version parsing failed, still prefer any migrated config.
  if [ "${#wallust_args[@]}" -eq 0 ]; then
    if [ -n "$v3_cfg" ]; then
      wallust_args=(--templates-dir "$wallust_templates_dir" -C "$v3_cfg")
    elif [ -n "$v4_cfg" ]; then
      wallust_args=(--templates-dir "$wallust_templates_dir" -C "$v4_cfg")
    fi
  fi
  if [ "${#wallust_kitty_args[@]}" -eq 0 ]; then
    if [ -n "$v3_kitty_cfg" ]; then
      wallust_kitty_args=(--templates-dir "$wallust_templates_dir" -C "$v3_kitty_cfg")
    elif [ -n "$v4_kitty_cfg" ]; then
      wallust_kitty_args=(--templates-dir "$wallust_templates_dir" -C "$v4_kitty_cfg")
    fi
  fi
}

# ---------------------------------------------------------------------------
# Palette source
#
# Which tool extracts the colours:
#   1. KOOLDOTS_PALETTE_SOURCE=butterpal|wallust   (environment, wins)
#   2. ${XDG_STATE_HOME:-$HOME/.local/state}/hypr/palette_source
#   3. butterpal when installed, otherwise wallust
# ---------------------------------------------------------------------------

wallust_palette_source_file() {
  printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/hypr/palette_source"
}

palette_source_is_butterpal() {
  [ "$palette_source" = "butterpal" ]
}

wallust_resolve_palette_source() {
  local requested="${KOOLDOTS_PALETTE_SOURCE:-}"
  local state_file
  state_file="$(wallust_palette_source_file)"

  if [ -z "$requested" ] && [ -f "$state_file" ]; then
    requested="$(tr -d '\r\n' < "$state_file" | awk '{$1=$1};1')"
  fi

  case "$requested" in
  butterpal | wallust)
    palette_source="$requested"
    ;;
  "")
    if command -v butterpal >/dev/null 2>&1; then
      palette_source="butterpal"
    else
      palette_source="wallust"
    fi
    ;;
  *)
    # An unrecognised value must not take every wallpaper change down with it.
    palette_source="wallust"
    ;;
  esac

  # butterpal is only useful when it is actually on PATH.
  if [ "$palette_source" = "butterpal" ] && ! command -v butterpal >/dev/null 2>&1; then
    palette_source="wallust"
  fi
}

# butterpal_palette_from_image <image>
#
# Runs `butterpal --json` and leaves the scheme where `wallust cs` reads it.
# Sets butterpal_palette_json and returns 0.
#
# butterpal emits a pywal colorscheme, which is a format wallust decodes
# directly, so only the accent slot is adjusted before it is passed on:
#
#   {"wallpaper": "...",
#    "special": {"background": "#...", "foreground": "#...",
#                "cursor": "#..."},
#    "colors": {"color0": "#...", ... "color15": "#..."}}
#
# `special.cursor` is butterpal's accent pick. The dots read color12 as their
# accent - borders, menus, bar - and wallust puts its accent in that slot, so
# butterpal's is moved there too and the templates stay on {{color12}}.
#
# That replaces butterpal's own ANSI blue at color12. Slot 12 follows the
# wallpaper under wallust as well, so the dots match wallust's behaviour
# rather than keeping a fixed blue.
#
# Returns 1 when no scheme can be produced - butterpal missing, an unreadable
# image, an unsupported format, unexpected output - so the caller can fall back
# to `wallust run`.
#
# butterpal reads PNG, JPEG, BMP and GIF. WebP and video wallpapers are not
# supported and take that fallback.
butterpal_palette_from_image() {
  local image="$1"
  local dir json

  if [ -z "$image" ] || [ ! -f "$image" ]; then
    return 1
  fi
  command -v butterpal >/dev/null 2>&1 || return 1

  dir="${XDG_CACHE_HOME:-$HOME/.cache}/butterpal"
  json="$dir/palette.json"
  mkdir -p "$dir" 2>/dev/null || return 1

  if ! butterpal --json "$image" >"$json" 2>/dev/null; then
    rm -f "$json"
    return 1
  fi

  # A scheme missing either section would render a template with an empty
  # colour, so treat it as no palette and let wallust run instead.
  [ -s "$json" ] || return 1
  grep -q '"special"' "$json" || return 1
  grep -q '"colors"' "$json" || return 1

  # The dots read color12 as their accent - borders, menus, bar. wallust puts
  # its accent in that slot, but butterpal keeps color12 ANSI blue for terminal
  # readability and puts its accent in cursor. Move it across here, so the
  # templates stay on color12 and neither source needs a template of its own.
  local accent
  accent="$(sed -n 's/.*"cursor":"\(#[0-9a-fA-F]\{6\}\)".*/\1/p' "$json" | head -n1)"
  if [ -n "$accent" ]; then
    sed -i "s/\"color12\":\"#[0-9a-fA-F]\{6\}\"/\"color12\":\"$accent\"/" "$json"
  fi

  butterpal_palette_json="$json"
  return 0
}

# wallust_cs_from_palette <config args...>
#
# Renders every template in the given wallust config from the scheme
# butterpal_palette_from_image wrote. -s matches the `wallust run -s` the repo
# already uses: skip terminal sequences, only regenerate files.
wallust_cs_from_palette() {
  [ -s "${butterpal_palette_json:-}" ] || return 1
  wallust cs "$@" -s -f pywal "$butterpal_palette_json"
}

wallust_prepare_args
wallust_resolve_palette_source
