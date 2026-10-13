#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   The installer replaces ~/.config/hypr and ~/.config/wlogout wholesale, so a
#   selection the user made lives in a directory that is thrown away. These are
#   the two restore helpers that put those selections back:
#
#     _carry_rofi_theme_selection   the active @theme line in config.rasi
#     restore_wlogout_selection     the saved wlogout preset
#
#   Both are exercised against a sandbox XDG_CONFIG_HOME with no session, no
#   compositor and no rofi. The wlogout applier is stubbed so the test asserts
#   WHAT was re-applied, not what an image renderer did with it.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

# lib_test.sh sets SCRIPT_DIR to the scripts directory; the installer helpers
# live at the repo root, three levels up.
REPO_SCRIPTS="$SCRIPT_DIR/../../../scripts"
REPO_ROOT="$SCRIPT_DIR/../../.."
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

# The suite is installed with the rest of config/hypr, but scripts/lib_copy.sh is
# not: it is repo-side, and only the installer runs it. Running from
# ~/.config/hypr/scripts/tests therefore finds no helpers, so say so and report
# clean instead of failing every check.
if [ ! -f "$REPO_SCRIPTS/lib_copy.sh" ] || [ ! -f "$REPO_SCRIPTS/lib_backup.sh" ]; then
  it "the installer helpers are not present here (repo-only test)"
  pass_msg
  summary "test-installer-selections"
  exit 0
fi

# shellcheck source=../../../scripts/lib_backup.sh
source "$REPO_SCRIPTS/lib_backup.sh"
# shellcheck source=../../../scripts/lib_copy.sh
source "$REPO_SCRIPTS/lib_copy.sh"

# Every helper reads XDG_CONFIG_HOME and the backup suffix; both are pinned so
# the assertions are about the helpers, not about where this machine happens to
# keep its config.
export XDG_CONFIG_HOME="$WORK/cfg"
export BACKUP_DIR="back-up_test"
LOG="$WORK/copy.log"
mkdir -p "$XDG_CONFIG_HOME"

# --- rofi: the theme selection ----------------------------------------------
NEW_CFG="$WORK/new-config.rasi"
OLD_CFG="$WORK/old-config.rasi"

seed_rofi() {  # <new-content> <old-content>
  printf '%s' "$1" >"$NEW_CFG"
  printf '%s' "$2" >"$OLD_CFG"
}

# The repo's own config: one import and one default @theme line.
REPO_CFG='@import "~/.config/hypr/rofi/0-shared-fonts.rasi"

@theme "~/.config/hypr/rofi/themes/KooL_style-4.rasi"
'
# What RofiThemeSelector.sh leaves behind: the previous theme commented out and
# the chosen one appended.
USER_CFG='@import "~/.config/hypr/rofi/0-shared-fonts.rasi"

//@theme "~/.config/hypr/rofi/themes/KooL_style-4.rasi"
@theme "~/.config/hypr/rofi/themes/KooL_style-6.rasi"
'

it "the rofi theme selection is carried into the freshly copied config"
seed_rofi "$REPO_CFG" "$USER_CFG"
_carry_rofi_theme_selection "$NEW_CFG" "$OLD_CFG" "$LOG"
assert_eq "exactly one active @theme line" '1' \
  "$(grep -cE '^[[:space:]]*@theme[[:space:]]' "$NEW_CFG")"

it "the carried line is the one the user chose"
assert_contains "$NEW_CFG" 'KooL_style-6.rasi' "the chosen theme won" && pass_msg

it "the repo's own default theme line is not left behind"
if grep -qE '^[[:space:]]*@theme[[:space:]].*KooL_style-4' "$NEW_CFG"; then
  fail "the repo default is still an active @theme line"
else pass_msg; fi

it "the new config's own imports survive the carry"
assert_contains "$NEW_CFG" '@import "~/.config/hypr/rofi/0-shared-fonts.rasi"' \
  "the import was kept" && pass_msg

it "an unchanged selection leaves the new config alone"
seed_rofi '@theme "~/.config/hypr/rofi/themes/KooL_style-6.rasi"
' '@theme "~/.config/hypr/rofi/themes/KooL_style-6.rasi"
'
before="$(cat "$NEW_CFG")"
_carry_rofi_theme_selection "$NEW_CFG" "$OLD_CFG" "$LOG"
assert_eq "byte-identical" "$before" "$(cat "$NEW_CFG")"

it "a backup with no active selection leaves the new config alone"
seed_rofi "$REPO_CFG" '@import "~/.config/hypr/rofi/0-shared-fonts.rasi"
'
before="$(cat "$NEW_CFG")"
_carry_rofi_theme_selection "$NEW_CFG" "$OLD_CFG" "$LOG"
assert_eq "byte-identical" "$before" "$(cat "$NEW_CFG")"

it "a missing backup config is a no-op"
seed_rofi "$REPO_CFG" ''
rm -f "$OLD_CFG"
if _carry_rofi_theme_selection "$NEW_CFG" "$OLD_CFG" "$LOG"; then pass_msg
else fail "must exit 0 with nothing to carry"; fi

# --- wlogout: the theme selection -------------------------------------------
WL="$XDG_CONFIG_HOME/wlogout"
WL_BACKUP="$WL-backup-$BACKUP_DIR"
export STUB_LOG="$WORK/wlogout-stub.log"

mkdir -p "$XDG_CONFIG_HOME/hypr/scripts"
cat >"$XDG_CONFIG_HOME/hypr/scripts/RofiWlogoutTheme.sh" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${STUB_LOG:-/dev/null}"
exit 0
EOS
chmod +x "$XDG_CONFIG_HOME/hypr/scripts/RofiWlogoutTheme.sh"

seed_wlogout() {  # <saved-theme>
  rm -rf "$WL" "$WL_BACKUP"
  # The freshly copied repo directory, back on its default preset.
  mkdir -p "$WL/themes/default"
  printf 'default\n' >"$WL/.current_theme"
  # What the previous install left in the backup.
  mkdir -p "$WL_BACKUP/themes/user_backup" "$WL_BACKUP/themes/BlueBerries"
  printf '%s\n' "$1" >"$WL_BACKUP/.current_theme"
  printf '30\n' >"$WL_BACKUP/.blur_radius"
  : >"$STUB_LOG"
}

it "the saved wlogout preset is re-applied after an upgrade"
seed_wlogout BlueBerries
restore_wlogout_selection "$LOG"
assert_contains "$STUB_LOG" '--set BlueBerries --silent' "the saved theme was re-applied" && pass_msg

it "a saved custom wlogout config is restored from the backup"
if [ -d "$WL/themes/user_backup" ]; then pass_msg
else fail "the user_backup preset was not restored"; fi

it "the wlogout blur preference is restored"
assert_eq "blur radius" '30' "$(cat "$WL/.blur_radius" 2>/dev/null)"

it "a default selection is not re-applied"
seed_wlogout default
restore_wlogout_selection "$LOG"
if [ -s "$STUB_LOG" ]; then fail "a theme was re-applied for 'default'"; else pass_msg; fi

it "a missing wlogout backup is a no-op"
seed_wlogout BlueBerries
rm -rf "$WL_BACKUP"
restore_wlogout_selection "$LOG"
if [ -s "$STUB_LOG" ]; then fail "a theme was re-applied with no backup"; else pass_msg; fi

it "an absent applier is reported, not fatal"
seed_wlogout BlueBerries
mv "$XDG_CONFIG_HOME/hypr/scripts/RofiWlogoutTheme.sh" "$WORK/applier.saved"
if restore_wlogout_selection "$LOG"; then pass_msg
else fail "must exit 0 when the applier is missing"; fi
mv "$WORK/applier.saved" "$XDG_CONFIG_HOME/hypr/scripts/RofiWlogoutTheme.sh"

# --- the picker reads the active preset back --------------------------------
# Without this the menu cannot mark the active preset, and apply_theme's
# auto-backup branch cannot tell what it is switching away from: it compares
# against an empty string, so it fires even when the current preset is default.
it "the wlogout picker reads the active preset from .current_theme"
QS="$WORK/qs"
mkdir -p "$QS/wlogout/themes/silvia" "$QS/wlogout/icons"
printf 'default\n' >"$QS/wlogout/.current_theme"
printf '* { }\n' >"$QS/wlogout/themes/silvia/style.css"
printf 'x\n' >"$QS/wlogout/themes/silvia/layout"
XDG_CONFIG_HOME="$QS" bash "$SCRIPT_DIR/RofiWlogoutTheme.sh" --set silvia --silent >/dev/null 2>&1
if [ -d "$QS/wlogout/themes/user_backup" ]; then
  fail "switching away from 'default' created a user_backup"
else pass_msg; fi

# --- wiring -----------------------------------------------------------------
it "restore_hypr_assets carries the rofi selection"
if sed -n '/^restore_hypr_assets()/,/^}/p' "$REPO_SCRIPTS/lib_copy.sh" \
   | grep -q '_carry_rofi_theme_selection'; then pass_msg
else fail "restore_hypr_assets does not carry the rofi theme selection"; fi

it "copy.sh calls the wlogout restore after the hypr assets"
assert_contains "$REPO_ROOT/copy.sh" 'restore_wlogout_selection' \
  "the restore is wired into the installer" && pass_msg

summary "test-installer-selections"
