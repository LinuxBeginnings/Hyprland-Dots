#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Applies non-destructive user-config patches (patches/*.sh) to an installed
# ~/.config/hypr/{UserConfigs,UserScripts} without overwriting user changes.
# Each patch is content-idempotent and safe to run on every install/upgrade.

# Capture the repo root relative to this helper at source time, so the runner
# does not depend on DOTFILES_DIR being set by the caller.
KOOLDOTS_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export KOOLDOTS_REPO_ROOT

apply_user_patches() {
  local log="${1:-/dev/null}"
  local base="${DOTFILES_DIR:-$KOOLDOTS_REPO_ROOT}"
  local patches_dir="$base/patches"

  if [ ! -d "$patches_dir" ]; then
    echo "${NOTE:-[NOTE]} - No user-config patches directory found; skipping." 2>&1 | tee -a "$log"
    return 0
  fi

  export KOOLDOTS_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
  export KOOLDOTS_LOG="$log"

  local patch_file patch_name applied=0
  shopt -s nullglob
  for patch_file in "$patches_dir"/*.sh; do
    patch_name="$(basename "$patch_file")"
    if [ "$patch_name" = "lib.sh" ]; then
      continue
    fi

    if [ ! -x "$patch_file" ]; then
      chmod +x "$patch_file" 2>/dev/null || true
    fi

    echo "${INFO:-[INFO]} - Applying user-config patch: ${YELLOW:-}$patch_name${RESET:-}" 2>&1 | tee -a "$log"
    if bash "$patch_file" 2>&1 | tee -a "$log"; then
      applied=$((applied + 1))
    else
      echo "${WARN:-[WARN]} - User-config patch ${YELLOW:-}$patch_name${RESET:-} reported a problem; continuing." 2>&1 | tee -a "$log"
    fi
  done
  shopt -u nullglob

  if [ "$applied" -eq 0 ]; then
    echo "${NOTE:-[NOTE]} - No user-config patches found to apply." 2>&1 | tee -a "$log"
  fi
  return 0
}
