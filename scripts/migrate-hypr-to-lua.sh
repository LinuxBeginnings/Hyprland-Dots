#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Opt-in helper for testing Hyprland's Lua config entrypoint.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC_HYPR_DIR="$REPO_DIR/config/hypr"
DEST_HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
BACKUP_DIR="${DEST_HYPR_DIR}-backup-lua-$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0
YES=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--yes] [--dry-run]

Copies the repo's Hyprland Lua entrypoint into:
  $DEST_HYPR_DIR

This preserves hyprland.conf as fallback and creates a full backup of the
current Hyprland config directory before changing files.

Options:
  -y, --yes      Run without confirmation prompts.
  -n, --dry-run  Show what would change without copying files.
  -h, --help     Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -y|--yes)
      YES=1
      ;;
    -n|--dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [ ! -f "$SRC_HYPR_DIR/hyprland.lua" ] || [ ! -d "$SRC_HYPR_DIR/lua" ]; then
  echo "[ERROR] Lua config source files were not found under $SRC_HYPR_DIR" >&2
  exit 1
fi

if command -v Hyprland >/dev/null 2>&1; then
  HYPR_VERSION="$(Hyprland --version 2>/dev/null | sed -n '1p' || true)"
  echo "[INFO] Detected $HYPR_VERSION"
else
  echo "[WARN] Hyprland binary was not found in PATH; continuing because this may be an offline config migration."
fi

echo "[INFO] Source: $SRC_HYPR_DIR"
echo "[INFO] Target: $DEST_HYPR_DIR"
echo "[INFO] Backup: $BACKUP_DIR"
echo "[WARN] This enables Hyprland's Lua entrypoint for builds that support hyprland.lua."
echo "[WARN] hyprland.conf remains in place as fallback; rollback is removing or renaming $DEST_HYPR_DIR/hyprland.lua."

if [ "$YES" -eq 0 ]; then
  printf "[ACTION] Continue with Lua config migration? [y/N] "
  read -r reply
  case "$reply" in
    [Yy]|[Yy][Ee][Ss])
      ;;
    *)
      echo "[INFO] Cancelled. No changes made."
      exit 0
      ;;
  esac
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY-RUN] Would create target directory if missing: $DEST_HYPR_DIR"
  if [ -d "$DEST_HYPR_DIR" ]; then
    echo "[DRY-RUN] Would copy backup: $DEST_HYPR_DIR -> $BACKUP_DIR"
  fi
  echo "[DRY-RUN] Would copy: $SRC_HYPR_DIR/hyprland.lua -> $DEST_HYPR_DIR/hyprland.lua"
  echo "[DRY-RUN] Would replace Lua module directory: $DEST_HYPR_DIR/lua"
  exit 0
fi

mkdir -p "$DEST_HYPR_DIR"

if [ -d "$DEST_HYPR_DIR" ] && [ -n "$(find "$DEST_HYPR_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
  cp -a "$DEST_HYPR_DIR" "$BACKUP_DIR"
  echo "[OK] Backup created at $BACKUP_DIR"
fi

cp -f "$SRC_HYPR_DIR/hyprland.lua" "$DEST_HYPR_DIR/hyprland.lua"
rm -rf "$DEST_HYPR_DIR/lua"
cp -a "$SRC_HYPR_DIR/lua" "$DEST_HYPR_DIR/lua"

echo "[OK] Lua Hyprland config copied."
echo "[INFO] Restart Hyprland to test Lua config pickup."
echo "[INFO] To rollback: mv '$DEST_HYPR_DIR/hyprland.lua' '$DEST_HYPR_DIR/hyprland.lua.disabled'"
