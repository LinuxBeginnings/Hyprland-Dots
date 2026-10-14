#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests for the indicator the Starship prompt menu puts on the prompt that is
#   loaded, and for the marker never reaching the symlink it creates.
#
#   The loaded prompt is the target of the starship.toml symlink, so that is
#   what the menu reads and what these cases assert on. A plain file where the
#   symlink should be is the user's own prompt, and nothing is marked then.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

SCRIPT="$HERE/../ChangeStarshipPrompt.sh"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

CFG="$WORK/cfg"
BIN="$WORK/bin"
STARSHIP_DIR="$CFG/starship"
STARSHIP_CONFIG="$CFG/starship.toml"
ROWS_FILE="$WORK/rows.txt"
ROFI_LOG="$WORK/rofi.log"
QUEUE="$WORK/queue.txt"
export ROWS_FILE ROFI_LOG QUEUE

mkdir -p "$STARSHIP_DIR" "$CFG/hypr/rofi" "$BIN"
: >"$CFG/hypr/rofi/config-starship.rasi"
printf 'add_newline = false\n' >"$STARSHIP_DIR/one.toml"
printf 'add_newline = true\n' >"$STARSHIP_DIR/two.toml"

# two.toml is the prompt loaded now.
ln -sfn "$STARSHIP_DIR/two.toml" "$STARSHIP_CONFIG"

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
exit 0
EOS

# The script refuses to run without starship; nothing here needs the real one.
cat >"$BIN/starship" <<'EOS'
#!/usr/bin/env bash
exit 0
EOS
chmod +x "$BIN"/*

# run_menu <queue entry>... - one menu run with those answers in order.
run_menu() {
  : >"$ROWS_FILE"; : >"$ROFI_LOG"
  printf '%s\n' "$@" >"$QUEUE"
  env PATH="$BIN:$PATH" XDG_CONFIG_HOME="$CFG" \
    timeout 30 bash "$SCRIPT" >"$WORK/out.txt" 2>&1
  return $?
}

# --- the loaded prompt is marked and its row is pre-selected ---------------
it "the loaded prompt is marked and its row is pre-selected"
run_menu __ESCAPE__
assert_contains "$ROWS_FILE" '👉 two.toml' "the loaded prompt carries the marker"
assert_not_contains "$ROWS_FILE" '👉 one.toml' "an unloaded prompt is left alone"
assert_contains "$ROFI_LOG" '-selected-row 1' "the marked row is pre-selected"
assert_contains "$ROFI_LOG" 'Current: two.toml' "the message line names it"

# --- Escape leaves the link alone -----------------------------------------
it "Escape leaves the symlink alone"
run_menu __ESCAPE__
assert_eq "the link still points at the loaded prompt" \
  "$STARSHIP_DIR/two.toml" "$(readlink -f "$STARSHIP_CONFIG")"

# --- choosing a marked row links the bare prompt --------------------------
# Without the strip the marker would be taken for part of the file name, the
# prompt would not be found, and the link would be left as it was.
it "the marker is stripped before the choice is used as a file name"
run_menu '0:👉 one.toml'
assert_eq "the link points at the chosen prompt" \
  "$STARSHIP_DIR/one.toml" "$(readlink -f "$STARSHIP_CONFIG")"
assert_not_contains "$(readlink "$STARSHIP_CONFIG")" '👉' "the marker is not in the link"

# --- a hand-written prompt is not a prompt from the list ------------------
it "a plain starship.toml marks nothing and reads as custom"
rm -f "$STARSHIP_CONFIG"
printf 'add_newline = false\n' >"$STARSHIP_CONFIG"
run_menu __ESCAPE__
assert_not_contains "$ROWS_FILE" '👉' "no prompt was marked"
assert_contains "$ROFI_LOG" 'Current: custom' "the message line says custom"

summary "test-starship-prompt-menu"
