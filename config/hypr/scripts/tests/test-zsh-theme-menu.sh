#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests for the indicator the Oh My Zsh theme menu puts on the theme that is
#   set, and for the marker never reaching the ZSH_THEME line.
#
#   HOME is sandboxed for this one: the menu reads and rewrites $HOME/.zshrc and
#   finds Oh My Zsh under $HOME, so the run must not touch the real dotfiles.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

SCRIPT="$HERE/../ZshChangeTheme.sh"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

CFG="$WORK/cfg"
BIN="$WORK/bin"
HOME_DIR="$WORK/home"
ZSHRC="$HOME_DIR/.zshrc"
OMZ="$HOME_DIR/.oh-my-zsh"
ROWS_FILE="$WORK/rows.txt"
ROFI_LOG="$WORK/rofi.log"
QUEUE="$WORK/queue.txt"
export ROWS_FILE ROFI_LOG QUEUE

mkdir -p "$CFG/hypr/rofi" "$BIN" "$OMZ/themes"
: >"$CFG/hypr/rofi/config-zsh-theme.rasi"

for t in agnoster clean robbyrussell; do
  printf '# %s theme\n' "$t" >"$OMZ/themes/$t.zsh-theme"
done

write_zshrc() {
  cat >"$ZSHRC" <<EOS
export ZSH="$OMZ"
ZSH_THEME="$1"
source \$ZSH/oh-my-zsh.sh
EOS
}
write_zshrc robbyrussell

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

# Nothing here may signal the session's own rofi.
cat >"$BIN/pidof" <<'EOS'
#!/usr/bin/env bash
exit 1
EOS
cat >"$BIN/pkill" <<'EOS'
#!/usr/bin/env bash
exit 0
EOS
chmod +x "$BIN"/*

# run_menu <queue entry>... - one menu run with those answers in order.
#
# ZSH, ZSH_CUSTOM and ZDOTDIR are cleared on purpose. The menu resolves Oh My
# Zsh from the environment first, so a real ZSH exported in the caller's shell
# would point it at the host's own Oh My Zsh and replace this fixture's three
# themes with hundreds. The marker still lands on the right row, so the run
# looks healthy, but every row index shifts and the -selected-row assertions
# fail against a row number that only the host's theme list produces.
run_menu() {
  : >"$ROWS_FILE"; : >"$ROFI_LOG"
  printf '%s\n' "$@" >"$QUEUE"
  env -u ZSH -u ZSH_CUSTOM -u ZDOTDIR \
    PATH="$BIN:$PATH" HOME="$HOME_DIR" XDG_CONFIG_HOME="$CFG" \
    timeout 30 bash "$SCRIPT" >"$WORK/out.txt" 2>&1
  return $?
}

# --- the theme that is set is marked and its row is pre-selected -----------
it "the theme that is set is marked and its row is pre-selected"
run_menu __ESCAPE__
assert_contains "$ROWS_FILE" '👉 robbyrussell' "the set theme carries the marker"
assert_not_contains "$ROWS_FILE" '👉 agnoster' "an unset theme is left alone"
assert_contains "$ROFI_LOG" '-selected-row 3' "the marked row is pre-selected"
assert_contains "$ROFI_LOG" 'Current: robbyrussell' "the message line names it"
pass_msg

# --- Escape leaves .zshrc alone -------------------------------------------
it "Escape leaves .zshrc alone"
run_menu __ESCAPE__
assert_eq "ZSH_THEME is unchanged" 'ZSH_THEME="robbyrussell"' \
  "$(grep '^ZSH_THEME=' "$ZSHRC")"

# --- choosing a marked row writes the bare theme name ---------------------
it "the marker is stripped before the theme is written to .zshrc"
run_menu '0:👉 agnoster'
assert_eq "the chosen theme was written without the marker" 'ZSH_THEME="agnoster"' \
  "$(grep '^ZSH_THEME=' "$ZSHRC")"

# --- Oh My Zsh's own random setting marks the Random row ------------------
it "a random ZSH_THEME marks the Random row"
write_zshrc random
run_menu __ESCAPE__
assert_contains "$ROWS_FILE" '👉 Random' "the Random row carries the marker"
assert_contains "$ROFI_LOG" '-selected-row 0' "the marked row is pre-selected"
pass_msg

summary "test-zsh-theme-menu"
