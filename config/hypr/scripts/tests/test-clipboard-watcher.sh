#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests for the wl-paste invocation in ClipboardWatcher.sh.
#
#   The bug guarded against here is that wl-paste, given no --type, infers the
#   MIME type it wants from the name of its own stdout. Startup runs the watcher
#   with stdout on /tmp/hypr-lua-startup-*.log (lua/user_startup_helper.lua), so
#   the inferred type was a text one: image-only offers were skipped silently and
#   cliphist only ever held text (issue #174). A fake wl-paste reports where its
#   own fd 1 points, so the test fails if the redirect is ever dropped again.
# No `set -e`: the assertion helpers return non-zero on failure.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

S="$HERE/.."
SCRIPT="$S/ClipboardWatcher.sh"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT
BIN="$WORK/bin"
CALL_LOG="$WORK/calls.log"
FD1="$WORK/fd1"
ERRFILE="$WORK/stderr"
mkdir -p "$BIN"
: >"$CALL_LOG"

# --- fake wl-paste ----------------------------------------------------------
# Records the command line, the target of its own stdout, and a line on stderr:
# the startup log is supposed to keep receiving the diagnostics.
cat >"$BIN/wl-paste" <<'EOS'
#!/usr/bin/env bash
printf 'wl-paste %s\n' "$*" >> "$FAKE_LOG"
readlink "/proc/$$/fd/1" > "$FAKE_FD1"
printf 'fake wl-paste diagnostic\n' >&2
exit 0
EOS
chmod +x "$BIN"/*

extract_fn() { sed -n "/^$2()/,/^}/p" -- "$1"; }

# --- the redirect -----------------------------------------------------------
it "wl-paste's stdout is /dev/null, not the inherited startup log"
if env PATH="$BIN:$PATH" FAKE_LOG="$CALL_LOG" FAKE_FD1="$FD1" \
    bash -c "$(extract_fn "$SCRIPT" watch_clipboard)"$'\n''watch_clipboard' \
    2>"$ERRFILE"; then
  target="$(cat "$FD1" 2>/dev/null)"
  if [[ "$target" == "/dev/null" ]]; then pass_msg
  else fail "wl-paste stdout points at '${target:-nothing}', so it infers a type from it"; fi
else
  fail "watch_clipboard exited non-zero"
fi

it "wl-paste still stores every offered type, with no --type of its own"
if assert_contains "$CALL_LOG" 'wl-paste --watch cliphist store' \
   && assert_not_contains "$CALL_LOG" '--type'; then pass_msg; fi

it "wl-paste's diagnostics still reach stderr, where the startup log collects them"
if assert_contains "$ERRFILE" 'fake wl-paste diagnostic'; then pass_msg; fi

# --- the shape of the script ------------------------------------------------
it "the watcher is started through exactly one invocation"
# Comments mention the command too; only the code lines count here.
count="$(grep -F 'wl-paste --watch' "$SCRIPT" | grep -vc '^[[:space:]]*#')"
if [[ "$count" == "1" ]]; then pass_msg
else fail "expected one wl-paste --watch invocation, found $count"; fi

it "that invocation is inside watch_clipboard, the function carrying the redirect"
if extract_fn "$SCRIPT" watch_clipboard | grep -qF 'wl-paste --watch cliphist store >/dev/null'; then pass_msg
else fail "the redirect is not on the wl-paste invocation itself"; fi

it "the restart loop still starts the watcher and reports its exit status"
main_loop="$(awk '/^while :; do/,/^done/' "$SCRIPT")"
if [[ "$main_loop" == *watch_clipboard* && "$main_loop" == *'status=$?'* ]]; then pass_msg
else fail "the supervisor no longer runs watch_clipboard, or lost its exit status"; fi

it "ClipboardWatcher.sh is still valid bash"
if bash -n "$SCRIPT" 2>/dev/null; then pass_msg
else fail "syntax error in ClipboardWatcher.sh"; fi

summary "test-clipboard-watcher"
