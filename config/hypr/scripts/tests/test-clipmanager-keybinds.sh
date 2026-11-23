#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests for the rofi keybindings in ClipManager.sh.
#
#   The bug guarded against here is that rofi built against libxkbcommon 1.8+
#   reports Meta as held together with Alt (rofi issue #2095), so a wipe bound
#   to plain `Alt+Delete` never matches and the key lands in the search box.
#   `Meta` cannot be named in a rofi binding, though: rofi has no Meta modifier
#   token and refuses the whole `-kb-custom-2` value with "Syntax error in
#   binding", the error dialog seen when the menu starts. Wipe is therefore
#   `Alt+Delete` plus `Control+Shift+Delete`, which uses only tokens every rofi
#   build parses. This test fails if either binding is dropped, if Meta comes
#   back, or if the exit codes stop calling cliphist as they did before.
# No `set -e`: the assertion helpers return non-zero on failure.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

SCRIPT="$(cd -- "$HERE/.." && pwd)/ClipManager.sh"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT
BIN="$WORK/bin"
CALL_LOG="$WORK/calls.log"
COUNTER="$WORK/rofi.count"
mkdir -p "$BIN" "$WORK/cfg/hypr/rofi"
: >"$CALL_LOG"

# --- fakes ------------------------------------------------------------------
# rofi records its argv and answers from FAKE_ROFI_FIRST on the first call, then
# exits 1 (cancel) so the script's loop terminates.
cat >"$BIN/rofi" <<'EOS'
#!/usr/bin/env bash
printf 'rofi %s\n' "$*" >> "$FAKE_LOG"
cat >/dev/null
n=0
[[ -s ${FAKE_COUNTER:-} ]] && n="$(cat "$FAKE_COUNTER")"
n=$((n + 1))
printf '%s\n' "$n" > "$FAKE_COUNTER"
if (( n == 1 )); then printf '%s\n' "second entry"; exit "$FAKE_ROFI_FIRST"; fi
exit 1
EOS

cat >"$BIN/cliphist" <<'EOS'
#!/usr/bin/env bash
printf 'cliphist %s\n' "$*" >> "$FAKE_LOG"
if [[ ${1:-} == "list" ]]; then
  [[ -n ${FAKE_CLIPHIST_EMPTY:-} ]] && exit 0
  printf 'first\nsecond entry\n'; exit 0
fi
cat >/dev/null
exit 0
EOS

cat >"$BIN/wl-copy" <<'EOS'
#!/usr/bin/env bash
printf 'wl-copy %s\n' "$*" >> "$FAKE_LOG"
exit 0
EOS

# The script kills its own previous menu by pattern; never the real rofi here.
cat >"$BIN/pkill" <<'EOS'
#!/usr/bin/env bash
printf 'pkill %s\n' "$*" >> "$FAKE_LOG"
exit 0
EOS

cat >"$BIN/notify-send" <<'EOS'
#!/usr/bin/env bash
printf 'notify-send %s\n' "$*" >> "$FAKE_LOG"
exit 0
EOS
chmod +x "$BIN"/*

# run_manager <rofi-exit-code> [empty] — one script run against fresh fakes.
# The second argument makes `cliphist list` answer with nothing.
run_manager() {
  : >"$CALL_LOG"
  rm -f "$COUNTER"
  env PATH="$BIN:$PATH" XDG_CONFIG_HOME="$WORK/cfg" \
    FAKE_LOG="$CALL_LOG" FAKE_COUNTER="$COUNTER" FAKE_ROFI_FIRST="$1" \
    FAKE_CLIPHIST_EMPTY="${2:-}" \
    bash "$SCRIPT"
}

it "rofi is asked for both Alt and Control+Shift, so a Meta-carrying build wipes"
if run_manager 11; then
  if assert_contains "$CALL_LOG" \
    '-kb-custom-2 Alt+Delete,Control+Shift+Delete' \
    'the wipe binding must list Alt+Delete and Control+Shift+Delete'; then pass_msg; fi
else
  fail "ClipManager.sh exited non-zero on the wipe path"
fi

it "CTRL DEL is still bound to Control+Delete alone"
if assert_contains "$CALL_LOG" '-kb-custom-1 Control+Delete' \
  'the single-entry binding changed'; then pass_msg; fi

it "no binding names Meta, which rofi rejects as a syntax error"
if grep -Eq -- '-kb-custom-[0-9]+ "[^"]*Meta' "$SCRIPT"; then
  fail "rofi has no Meta modifier token; naming it disables the whole binding"
else pass_msg; fi

it "a single-entry delete still asks cliphist to delete that entry"
if run_manager 10; then
  if assert_contains "$CALL_LOG" 'cliphist delete'; then pass_msg; fi
else
  fail "ClipManager.sh exited non-zero on the delete path"
fi

it "exit 11 still wipes the history and clears the live selection"
# run_manager 11 was consumed by the first test above; run it again.
if run_manager 11; then
  if assert_contains "$CALL_LOG" 'cliphist wipe' \
    && assert_contains "$CALL_LOG" 'wl-copy --clear'; then pass_msg; fi
else
  fail "ClipManager.sh exited non-zero on the wipe path"
fi

it "the menu is reopened after a wipe, so the history is shown empty"
count="$(grep -c '^rofi ' "$CALL_LOG" || true)"
if [[ "$count" == "2" ]]; then pass_msg
else fail "expected the list to reopen once after the wipe, saw $count rofi calls"; fi

it "an empty history notifies instead of opening an empty menu"
if run_manager 0 empty; then
  if grep -q '^rofi ' "$CALL_LOG"; then
    fail "rofi was launched while the history was empty"
  elif assert_contains "$CALL_LOG" 'Clipboard history is empty' \
    'the empty history must be reported to the user'; then
    pass_msg
  fi
else
  fail "ClipManager.sh exited non-zero when the history was empty"
fi

it "ClipManager.sh is still valid bash"
if bash -n "$SCRIPT" 2>/dev/null; then pass_msg
else fail "syntax error in ClipManager.sh"; fi

summary "test-clipmanager-keybinds"
