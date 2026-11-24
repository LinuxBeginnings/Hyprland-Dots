#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Verifies that copy_waybar and sync_waybar_config merge waybar
#   configurations in place using rsync without deleting user-created
#   configs, styles, or modules.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

REPO_SCRIPTS="$SCRIPT_DIR/../../../scripts"
REPO_ROOT="$SCRIPT_DIR/../../.."
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

if [ ! -f "$REPO_SCRIPTS/lib_copy.sh" ] || [ ! -f "$REPO_SCRIPTS/lib_backup.sh" ]; then
  it "the installer helpers are not present here (repo-only test)"
  pass_msg
  summary "test-waybar-merge"
  exit 0
fi

# shellcheck source=../../../scripts/lib_backup.sh
source "$REPO_SCRIPTS/lib_backup.sh"
# shellcheck source=../../../scripts/lib_copy.sh
source "$REPO_SCRIPTS/lib_copy.sh"

export XDG_CONFIG_HOME="$WORK/cfg"
export BACKUP_DIR="back-up_test"
export DOTFILES_DIR="$REPO_ROOT"
LOG="$WORK/copy.log"
mkdir -p "$XDG_CONFIG_HOME"

WAYBAR_DIR="$XDG_CONFIG_HOME/hypr/waybar"

# --- 1. sync_waybar_config preserves user configs and styles in place --------
mkdir -p "$WAYBAR_DIR/configs" "$WAYBAR_DIR/style" "$WAYBAR_DIR/styles" "$WAYBAR_DIR/wallust"

printf 'user-custom-layout-content\n' > "$WAYBAR_DIR/configs/User-Custom-Layout"
printf 'user-custom-style-content\n' > "$WAYBAR_DIR/style/User-Custom-Style.css"
printf 'user-plural-style-content\n' > "$WAYBAR_DIR/styles/Custom-Extra.css"
printf '{"custom/user": {"format": "User"}}\n' > "$WAYBAR_DIR/UserModules"
printf '/* user wallust palette */\n' > "$WAYBAR_DIR/wallust/colors-waybar.css"

ln -sf "$WAYBAR_DIR/configs/User-Custom-Layout" "$WAYBAR_DIR/config"
ln -sf "$WAYBAR_DIR/style/User-Custom-Style.css" "$WAYBAR_DIR/style.css"

it "sync_waybar_config completes successfully"
if sync_waybar_config "$LOG"; then pass_msg
else fail "sync_waybar_config returned non-zero"; fi

it "user custom layout in configs/ is preserved"
assert_eq "layout content preserved" "user-custom-layout-content" \
  "$(cat "$WAYBAR_DIR/configs/User-Custom-Layout" 2>/dev/null)"

it "user custom style in style/ is preserved"
assert_eq "style content preserved" "user-custom-style-content" \
  "$(cat "$WAYBAR_DIR/style/User-Custom-Style.css" 2>/dev/null)"

it "user custom file in styles/ (plural) is preserved"
assert_eq "styles content preserved" "user-plural-style-content" \
  "$(cat "$WAYBAR_DIR/styles/Custom-Extra.css" 2>/dev/null)"

it "user custom UserModules is preserved"
assert_contains "$WAYBAR_DIR/UserModules" '"custom/user"' \
  "UserModules was not overwritten by repo template" && pass_msg

it "user wallust runtime files are preserved"
assert_contains "$WAYBAR_DIR/wallust/colors-waybar.css" 'user wallust palette' \
  "wallust was not overwritten" && pass_msg

it "active config symlink to user custom layout is preserved"
assert_eq "config symlink preserved" "$WAYBAR_DIR/configs/User-Custom-Layout" \
  "$(readlink "$WAYBAR_DIR/config" 2>/dev/null)"

it "active style.css symlink to user custom style is preserved"
assert_eq "style.css symlink preserved" "$WAYBAR_DIR/style/User-Custom-Style.css" \
  "$(readlink "$WAYBAR_DIR/style.css" 2>/dev/null)"

it "repo-managed layouts are present"
if [ -f "$WAYBAR_DIR/configs/TOP-Default" ]; then pass_msg
else fail "TOP-Default was not installed by rsync merge"; fi

it "repo-managed styles are present"
if [ -f "$WAYBAR_DIR/style/Extra-Prismatic-Glow.css" ]; then pass_msg
else fail "Extra-Prismatic-Glow.css was not installed by rsync merge"; fi

it "a safety backup was taken before merging"
if find "$XDG_CONFIG_HOME/hypr" -maxdepth 1 -type d -name "waybar-backup-*" | grep -q .; then pass_msg
else fail "safety backup directory was not created"; fi

# --- 2. In-place stale path repair ------------------------------------------
STALE_FILE="$WAYBAR_DIR/configs/stale-custom"
printf '$HOME/.config/waybar/UserModules\n' > "$STALE_FILE"
CSS_STALE="$WAYBAR_DIR/style/stale-import.css"
printf "@import '../../.config/waybar/wallust/colors-waybar.css';\n" > "$CSS_STALE"

_repair_waybar_stale_paths "$WAYBAR_DIR" "$LOG"

it "stale path references are rewritten in place"
assert_contains "$STALE_FILE" '$HOME/.config/hypr/waybar/UserModules' \
  "path was rewritten to hypr/waybar" && pass_msg

it "stale wallust imports are rewritten in place"
assert_contains "$CSS_STALE" '../../../.config/hypr/waybar/wallust/colors-waybar.css' \
  "wallust import was rewritten" && pass_msg

# --- 3. Broken symlinks are repaired to valid defaults ----------------------
rm -f "$WAYBAR_DIR/config" "$WAYBAR_DIR/style.css"
ln -sf "/nonexistent/path" "$WAYBAR_DIR/config"
ln -sf "/nonexistent/style.css" "$WAYBAR_DIR/style.css"

_ensure_waybar_symlinks "$WAYBAR_DIR" "$LOG"

it "broken config link is repaired to default layout"
assert_eq "repaired config basename" "TOP-Default" \
  "$(basename "$(readlink "$WAYBAR_DIR/config")")"

it "broken style.css link is repaired to default style"
assert_eq "repaired style.css basename" "Extra-Prismatic-Glow.css" \
  "$(basename "$(readlink "$WAYBAR_DIR/style.css")")"

# --- 4. copy_waybar in express mode merges without deleting -----------------
printf 'express-preserved-layout\n' > "$WAYBAR_DIR/configs/Express-Layout"
copy_waybar "$LOG" "express"

it "copy_waybar in express mode preserves custom files"
assert_eq "express preserved" "express-preserved-layout" \
  "$(cat "$WAYBAR_DIR/configs/Express-Layout" 2>/dev/null)"

summary "test-waybar-merge"
