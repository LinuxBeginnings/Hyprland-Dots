#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Shared helpers for KoolDots user-config patches.
#
# Contract for a patch script (patches/NN-name.sh):
#   * Executed by scripts/lib_patches.sh (apply_user_patches), in sorted order.
#   * Must be content-idempotent: detect whether its fix is already present
#     and leave the file unchanged if so.
#   * Targets live under $KOOLDOTS_CONFIG_HOME/hypr - i.e. UserConfigs/ and
#     UserScripts/. Skip cleanly (exit 0) when a target file is absent.
#   * Never rewrite a whole file: only add/adjust the specific setting, so a
#     user's own edits are preserved.
#   * Exit 0 for both "applied" and "already present/skipped".
#   * Log through patch_log(); the runner also captures stdout/stderr.

KOOLDOTS_CONFIG_HOME="${KOOLDOTS_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}"
KOOLDOTS_LOG="${KOOLDOTS_LOG:-/dev/null}"

patch_log() {
  echo "${NOTE:-[NOTE]} - [patch] $*" 2>&1 | tee -a "$KOOLDOTS_LOG"
}

# patch_hypr_dir: absolute path to the installed hypr config directory.
patch_hypr_dir() {
  printf '%s' "$KOOLDOTS_CONFIG_HOME/hypr"
}

# patch_ensure_line <file> <present-extended-regex> <line>
# Append <line> to <file> when no line matches <present-extended-regex>.
patch_ensure_line() {
  local file="$1" present_re="$2" line="$3"
  [ -f "$file" ] || return 0
  if grep -qE "$present_re" "$file" 2>/dev/null; then
    return 0
  fi
  printf '%s\n' "$line" >>"$file"
}

# patch_ensure_line_after <file> <anchor-extended-regex> <present-extended-regex> <line>
# Insert <line> immediately after the first line matching <anchor-extended-regex>
# when no line matches <present-extended-regex>. Falls back to appending when the
# anchor is not found. The file is rewritten in place to preserve its inode and
# permissions.
patch_ensure_line_after() {
  local file="$1" anchor_re="$2" present_re="$3" line="$4"
  [ -f "$file" ] || return 0

  if grep -qE "$present_re" "$file" 2>/dev/null; then
    return 0
  fi

  if ! grep -qE "$anchor_re" "$file" 2>/dev/null; then
    printf '%s\n' "$line" >>"$file"
    return 0
  fi

  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/kooldots-patch.XXXXXX")" || return 1
  if awk -v anchor="$anchor_re" -v ins="$line" '
      { print }
      !done && $0 ~ anchor { print ins; done = 1 }
    ' "$file" >"$tmp"; then
    cat "$tmp" >"$file"
    rm -f "$tmp"
    return 0
  fi
  rm -f "$tmp"
  return 1
}
