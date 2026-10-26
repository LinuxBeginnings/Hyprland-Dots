#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests for the indicator the Kitty theme menu puts on the theme that is
#   loaded, and for the marker never reaching the kitty.conf include line.
#
#   The menu is a preview loop: Enter rewrites the include line and reopens, and
#   Ctrl+S (exit 10) applies and leaves. Both paths are driven here against a
#   sandbox XDG_CONFIG_HOME, so no session and no kitty process are involved.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

SCRIPT="$HERE/../Kitty_themes.sh"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

CFG="$WORK/cfg"
BIN="$WORK/bin"
THEMES="$CFG/hypr/UserConfigs/kitty-themes"
KITTY_CONF="$CFG/hypr/UserConfigs/kitty.conf"
ROWS_FILE="$WORK/rows.txt"
ROFI_LOG="$WORK/rofi.log"
NOTIFY_LOG="$WORK/notify.log"
QUEUE="$WORK/queue.txt"
export ROWS_FILE ROFI_LOG NOTIFY_LOG QUEUE

mkdir -p "$THEMES" "$CFG/hypr/rofi" "$CFG/hypr/scripts" "$BIN"
: >"$CFG/hypr/rofi/config-kitty-theme.rasi"

# 00/01 are the wallpaper and default entries the menu hides behind its own
# labels; Alpha and Beta are ordinary themes.
for t in 00-Default 01-Wallust Alpha Beta; do
  printf 'background #000000\n' >"$THEMES/$t.conf"
done

# Beta is the theme loaded now.
printf 'include ~/.config/hypr/UserConfigs/kitty-themes/Beta.conf\n' >"$KITTY_CONF"

# Fake rofi. Every call overwrites the recorded rows (the loop reopens the same
# list, so the last call is the one to judge). QUEUE holds one entry per call:
# "<exit code>:<text>" answers with that text, or __ESCAPE__ to cancel.
cat >"$BIN/rofi" <<'EOS'
#!/usr/bin/env bash
printf 'rofi %s\n' "$*" >>"$ROFI_LOG"
cat >"$ROWS_FILE"
if [[ -s "$QUEUE" ]]; then
  entry="$(head -n1 "$QUEUE")"
  tail -n +2 "$QUEUE" >"$QUEUE.rest" && mv "$QUEUE.rest" "$QUEUE"
  if [[ "$entry" != "__ESCAPE__" ]]; then
    printf '%s\n' "${entry#*:}"
    exit "${entry%%:*}"
  fi
fi
exit 1
EOS

cat >"$BIN/notify-send" <<'EOS'
#!/usr/bin/env bash
printf 'notify-send %s\n' "$*" >>"$NOTIFY_LOG"
exit 0
EOS

# pidof answers "not running" for everything, so the script never signals a real
# kitty or kills the session's own rofi.
cat >"$BIN/pidof" <<'EOS'
#!/usr/bin/env bash
exit 1
EOS
chmod +x "$BIN"/*

# run_menu <queue entry>... - one menu run with those answers in order.
run_menu() {
  : >"$ROWS_FILE"; : >"$ROFI_LOG"; : >"$NOTIFY_LOG"
  printf '%s\n' "$@" >"$QUEUE"
  env PATH="$BIN:$PATH" XDG_CONFIG_HOME="$CFG" XDG_CACHE_HOME="$WORK/cache" \
    timeout 30 bash "$SCRIPT" >"$WORK/out.txt" 2>&1
  return $?
}

# --- the loaded theme is marked and its row is pre-selected -----------------
it "the loaded theme is marked and its row is pre-selected"
run_menu __ESCAPE__
assert_contains "$ROWS_FILE" '👉 Beta' "the loaded theme carries the marker"
assert_not_contains "$ROWS_FILE" '👉 Alpha' "an unloaded theme is left alone"
assert_contains "$ROFI_LOG" '-selected-row 3' "the marked row is pre-selected"
assert_contains "$ROFI_LOG" 'Current: Beta' "the message line names it"

# --- Escape leaves the config alone ----------------------------------------
it "Escape leaves the include line alone"
run_menu __ESCAPE__
assert_contains "$KITTY_CONF" 'kitty-themes/Beta.conf' "the include line is unchanged"
assert_not_contains "$KITTY_CONF" '👉' "no marker reached the config"

# --- choosing the marked row by name applies the bare theme ----------------
# The menu asks for an index, but a marker that reached the name lookup would
# match nothing: the apply would be dropped, the menu would reopen, and the
# answer after it (none) would be read as a cancel and revert the preview. So
# the give-away is the cancel and the extra menu, not the include line - the
# revert puts the same theme back.
it "the marker is stripped before the choice is used as a theme name"
run_menu '0:2' '10:👉 Beta'
assert_contains "$KITTY_CONF" 'kitty-themes/Beta.conf' "the marked theme was applied"
assert_not_contains "$KITTY_CONF" '👉' "the marker was not written into the config"
assert_not_contains "$NOTIFY_LOG" 'cancelled' "the apply was not read as a cancel"
assert_count_re 2 "$ROFI_LOG" '^rofi ' "the menu closed instead of reopening"

# --- a preview by index, then Ctrl+S on a different theme ------------------
it "a preview then an apply land on the chosen theme"
run_menu '0:2' '10:Alpha'
assert_contains "$KITTY_CONF" 'kitty-themes/Alpha.conf' "the applied theme won"
assert_not_contains "$KITTY_CONF" 'Beta.conf' "the previewed theme was replaced"

summary "test-kitty-theme-menu"
