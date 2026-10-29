#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests for the indicator the Ghostty theme menu puts on the entry that is in
#   effect, and for the marker never reaching the `theme =` line.
#
#   This menu reads its choices back as text - the labels and the theme names
#   are compared after rofi returns - so the strip is what keeps a marked row
#   from being read as a theme called "👉 Nord".
#
#   It also covers the source tag Ghostty puts on each name from +list-themes.
#   Ghostty 1.4.0 tags the bundled collection "(resources)"; an earlier filter
#   stripped only "(user)" and "(builtin)", so the exact match missed and every
#   built-in theme was read as missing. The menu then offered only the themes
#   that happened to be files in the user theme directory.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

SCRIPT="$HERE/../Ghostty_themes.sh"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

CFG="$WORK/cfg"
BIN="$WORK/bin"
CONFIG="$CFG/hypr/UserConfigs/ghostty.conf"
ROWS_FILE="$WORK/rows.txt"
ROFI_LOG="$WORK/rofi.log"
NOTIFY_LOG="$WORK/notify.log"
QUEUE="$WORK/queue.txt"
export ROWS_FILE ROFI_LOG NOTIFY_LOG QUEUE

mkdir -p "$CFG/hypr/UserConfigs" "$CFG/hypr/rofi" "$CFG/ghostty/themes" "$BIN"
: >"$CFG/hypr/rofi/config-ghostty-theme.rasi"

# A theme is offered only when Ghostty can resolve it, which here means a file
# in the user theme directory.
for t in Nord Dracula; do
  printf 'background = 000000\n' >"$CFG/ghostty/themes/$t"
done

# Dracula is active; the commented lines are what the menu offers.
cat >"$CONFIG" <<'EOS'
theme = Dracula
#theme = Nord
#theme = Dracula
EOS

# Fake rofi: records the rows and arguments, then answers with the next QUEUE
# entry ("<exit>:<text>"), or cancels on __ESCAPE__.
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

# Hermetic: the real ghostty's own theme list must not leak into the run, and
# nothing may signal a running terminal. +list-themes is the path under test,
# so the fake prints the same tagged shape the real one does.
cat >"$BIN/ghostty" <<'EOS'
#!/usr/bin/env bash
if [[ "${1:-}" == "+list-themes" && -n "${FAKE_GHOSTTY_THEMES:-}" ]]; then
  printf '%s\n' "$FAKE_GHOSTTY_THEMES"
fi
exit 0
EOS
cat >"$BIN/pkill" <<'EOS'
#!/usr/bin/env bash
exit 0
EOS
chmod +x "$BIN"/*

# run_menu <queue entry>... - one menu run with those answers in order.
run_menu() {
  : >"$ROWS_FILE"; : >"$ROFI_LOG"; : >"$NOTIFY_LOG"
  printf '%s\n' "$@" >"$QUEUE"
  # -u GHOSTTY_RESOURCES_DIR: with it set, a theme resolves through the
  # resources path and the +list-themes check is never reached, so the tag
  # case below would pass without testing anything.
  env -u GHOSTTY_RESOURCES_DIR PATH="$BIN:$PATH" XDG_CONFIG_HOME="$CFG" \
    FAKE_GHOSTTY_THEMES="${FAKE_GHOSTTY_THEMES:-}" \
    timeout 30 bash "$SCRIPT" >"$WORK/out.txt" 2>&1
  return $?
}

# --- the active theme is marked and its row is pre-selected -----------------
it "the active theme is marked and its row is pre-selected"
run_menu __ESCAPE__
assert_contains "$ROWS_FILE" '👉 Dracula' "the active theme carries the marker"
assert_not_contains "$ROWS_FILE" '👉 Nord' "an inactive theme is left alone"
assert_contains "$ROFI_LOG" '-selected-row 3' "the marked row is pre-selected"
assert_contains "$ROFI_LOG" 'Current: Dracula' "the message line names it"

# --- Escape leaves the config alone ----------------------------------------
it "Escape leaves the config alone"
run_menu __ESCAPE__
assert_contains "$CONFIG" 'theme = Dracula' "the active theme is unchanged"
assert_not_contains "$CONFIG" '👉' "no marker reached the config"

# --- choosing a marked row applies the bare theme name ---------------------
it "the marker is stripped before the choice is read as a theme name"
run_menu '0:👉 Nord'
assert_contains "$CONFIG" 'theme = Nord' "the chosen theme was applied"
assert_not_contains "$CONFIG" '👉' "the marker was not written into the config"

# --- a theme known only from +list-themes is still offered ----------------
# No file for Aura, so only the +list-themes path can make it available.
it "a theme advertised only through +list-themes is offered"
printf 'theme = Dracula\n#theme = Aura\n' >"$CONFIG"
rm -f "$CFG/ghostty/themes/Aura"
FAKE_GHOSTTY_THEMES='Aura (resources)'
run_menu __ESCAPE__
assert_contains "$ROWS_FILE" 'Aura' "the tagged name is recognised"
assert_not_contains "$ROWS_FILE" '(resources)' "the tag is not shown as part of the name"
FAKE_GHOSTTY_THEMES=''

# --- a marked label is still a label ---------------------------------------
it "a marked label is still read as the label it is"
printf '#theme = Nord\n#theme = Dracula\n' >"$CONFIG"
run_menu '0:👉 Default - no color'
assert_contains "$ROFI_LOG" '-selected-row 1' "the default entry is the marked row"
assert_not_contains "$NOTIFY_LOG" '👉' "the marker was not reported as a theme"
assert_not_contains "$CONFIG" '👉' "the marker was not written into the config"

summary "test-ghostty-theme-menu"
