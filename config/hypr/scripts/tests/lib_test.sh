#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Minimal assertion helpers and fake-command sandbox shared by the
#   display-profile test scripts. No external test framework required.

TESTS_RUN=0
TESTS_FAILED=0
CURRENT_TEST=""

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd -- "$TEST_DIR/.." && pwd)"
FIXTURES="$TEST_DIR/fixtures"

it() {
  CURRENT_TEST="$1"
  TESTS_RUN=$((TESTS_RUN + 1))
}

fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf 'FAIL: %s\n      %s\n' "$CURRENT_TEST" "$1" >&2
}

pass_msg() { printf 'ok   %s\n' "$CURRENT_TEST"; }

# assert_contains <haystack-file-or-string> <needle> [label]
assert_contains() {
  local haystack=$1 needle=$2 label=${3:-}
  if [[ -f $haystack ]]; then
    grep -qF -- "$needle" "$haystack" && return 0
  else
    [[ $haystack == *"$needle"* ]] && return 0
  fi
  fail "expected to find '$needle' ${label:+($label)}"
  return 1
}

assert_not_contains() {
  local haystack=$1 needle=$2 label=${3:-}
  if [[ -f $haystack ]]; then
    grep -qF -- "$needle" "$haystack" || return 0
  else
    [[ $haystack != *"$needle"* ]] && return 0
  fi
  fail "expected NOT to find '$needle' ${label:+($label)}"
  return 1
}

# assert_order <file> <first> <second>
assert_order() {
  local file=$1 first=$2 second=$3
  local a b
  a=$(grep -nF -- "$first" "$file" | head -1 | cut -d: -f1)
  b=$(grep -nF -- "$second" "$file" | head -1 | cut -d: -f1)
  if [[ -z $a ]]; then fail "ordering: '$first' never appeared"; return 1; fi
  if [[ -z $b ]]; then fail "ordering: '$second' never appeared"; return 1; fi
  if (( a < b )); then return 0; fi
  fail "ordering: '$first' (line $a) must come before '$second' (line $b)"
  return 1
}

assert_status() {
  local expected=$1 actual=$2 label=${3:-}
  [[ $expected == "$actual" ]] && return 0
  fail "expected exit status $expected, got $actual ${label:+($label)}"
  return 1
}

assert_count() {
  local expected=$1 file=$2 pattern=$3
  local actual
  actual=$(grep -cF -- "$pattern" "$file" || true)
  [[ $actual == "$expected" ]] && return 0
  fail "expected $expected occurrences of '$pattern', got $actual"
  return 1
}

# assert_count_re <expected> <file> <extended-regex>
# Needed where a plain substring is ambiguous: "waybar -c" also appears inside
# the recorded `pgrep -af "waybar -c ..."` line.
assert_count_re() {
  local expected=$1 file=$2 pattern=$3
  local actual
  actual=$(grep -cE -- "$pattern" "$file" || true)
  [[ $actual == "$expected" ]] && return 0
  fail "expected $expected lines matching /$pattern/, got $actual"
  return 1
}

assert_eq() {
  local label=$1 expected=$2 actual=$3
  it "$label"
  [[ $actual == "$expected" ]] && { pass_msg; return 0; }
  fail "expected '$expected', got '$actual'"
  return 1
}

# assert_json_eq <file> <jq-filter> <expected>
# jq -r on a file, compared as a string. Keeps JSON assertions out of the
# shell's quoting rules, which is where the first draft of these tests went
# wrong most often.
assert_json_eq() {
  local file=$1 filter=$2 expected=$3 actual
  it "jq '$filter' on $(basename -- "$file") is $expected"
  actual="$(jq -r "$filter" -- "$file" 2>&1 || true)"
  [[ $actual == "$expected" ]] && { pass_msg; return 0; }
  fail "expected '$expected', got '$actual'"
  return 1
}

# check <label> <command...>  — asserts the command succeeds.
check() {
  local label=$1; shift
  it "$label"
  if "$@" >/dev/null 2>&1; then pass_msg; return 0; fi
  fail "command failed: $*"
  return 1
}

summary() {
  printf '\n%s: %d run, %d failed\n' "${1:-tests}" "$TESTS_RUN" "$TESTS_FAILED"
  (( TESTS_FAILED == 0 ))
}

# ---------------------------------------------------------------------------
# Fake command sandbox
# ---------------------------------------------------------------------------
# make_sandbox creates a throwaway dir with fake hyprctl/waybar/pgrep/pkill/
# notify-send/systemctl on PATH. Every invocation is appended to $CALL_LOG.
make_sandbox() {
  SANDBOX=$(mktemp -d)
  BIN="$SANDBOX/bin"
  mkdir -p "$BIN" "$SANDBOX/runtime"
  CALL_LOG="$SANDBOX/calls.log"
  : > "$CALL_LOG"

  FAKE_MONITORS="$FIXTURES/laptop-only.json"
  FAKE_MONITORS_ALL="$FIXTURES/laptop-only.json"
  FAKE_PGREP_OUT="$SANDBOX/pgrep.out"
  printf '4450 waybar\n' > "$FAKE_PGREP_OUT"

  cat > "$BIN/hyprctl" <<'EOS'
#!/usr/bin/env bash
printf 'hyprctl %s\n' "$*" >> "$CALL_LOG"
if [[ ${1:-} == "-j" && ${2:-} == "monitors" ]]; then
  if [[ ${3:-} == "all" ]]; then cat "$FAKE_MONITORS_ALL"; exit 0; fi
  # FAKE_MONITORS_SEQ holds one fixture path per line, consumed one per call.
  # Needed because a single fixture cannot both satisfy a monitor verification
  # and then report nothing active.
  if [[ -n ${FAKE_MONITORS_SEQ:-} && -s ${FAKE_MONITORS_SEQ:-} ]]; then
    next="$(head -n1 "$FAKE_MONITORS_SEQ")"
    tail -n +2 "$FAKE_MONITORS_SEQ" > "$FAKE_MONITORS_SEQ.rest" && mv "$FAKE_MONITORS_SEQ.rest" "$FAKE_MONITORS_SEQ"
    [[ -n $next && -f $next ]] && { cat "$next"; exit 0; }
  fi
  cat "$FAKE_MONITORS"
  exit 0
fi
# Hyprland answers some failures on stdout with exit status 0; the tests need
# to reproduce that.
[[ -n ${FAKE_HYPRCTL_STDOUT:-} ]] && printf '%s\n' "$FAKE_HYPRCTL_STDOUT"
exit "${FAKE_HYPRCTL_EXIT:-0}"
EOS

  # The real waybar keeps running after the controller exits. That matters:
  # a long-lived child inherits open file descriptors, including any lock.
  cat > "$BIN/waybar" <<'EOS'
#!/usr/bin/env bash
printf 'waybar %s\n' "$*" >> "$CALL_LOG"
if [[ -n ${FAKE_WAYBAR_LINGER:-} ]]; then exec sleep "$FAKE_WAYBAR_LINGER"; fi
exit 0
EOS

  cat > "$BIN/pgrep" <<'EOS'
#!/usr/bin/env bash
printf 'pgrep %s\n' "$*" >> "$CALL_LOG"
if [[ -s ${FAKE_PGREP_OUT:-/dev/null} ]]; then
  # emulate -f: the pattern is matched against the recorded cmdline
  for arg in "$@"; do
    case $arg in -*) continue ;; esac
    grep -qF -- "$arg" "$FAKE_PGREP_OUT" || exit 1
  done
  cat "$FAKE_PGREP_OUT"
  exit 0
fi
exit 1
EOS

  cat > "$BIN/pkill" <<'EOS'
#!/usr/bin/env bash
printf 'pkill %s\n' "$*" >> "$CALL_LOG"
exit 0
EOS

  cat > "$BIN/notify-send" <<'EOS'
#!/usr/bin/env bash
printf 'notify-send %s\n' "$*" >> "$CALL_LOG"
exit 0
EOS

  cat > "$BIN/systemctl" <<'EOS'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >> "$CALL_LOG"
exit 0
EOS

  cat > "$BIN/nwg-displays" <<'EOS'
#!/usr/bin/env bash
printf 'nwg-displays %s\n' "$*" >> "$CALL_LOG"
# The real GUI lives long enough for the pause file's PID to be alive, which is
# the whole point of the pause protocol.
if [[ -n ${FAKE_NWG_LINGER:-} ]]; then exec sleep "$FAKE_NWG_LINGER"; fi
exit "${FAKE_NWG_EXIT:-0}"
EOS

  # systemd-run must still start the trailing command, or the Waybar restart
  # path would look like it worked while nothing ran.
  cat > "$BIN/systemd-run" <<'EOS'
#!/usr/bin/env bash
printf 'systemd-run %s\n' "$*" >> "$CALL_LOG"
seen_sep=0
cmd=()
for a in "$@"; do
  if (( seen_sep )); then cmd+=("$a"); continue; fi
  [[ $a == "--" ]] && seen_sep=1
done
if (( ${#cmd[@]} )); then "${cmd[@]}" >/dev/null 2>&1 & fi
exit 0
EOS

  cat > "$BIN/rofi" <<'EOS'
#!/usr/bin/env bash
printf 'rofi %s\n' "$*" >> "$CALL_LOG"
rows="$(cat)"
if [[ -n ${FAKE_ROFI_DUMP_ROWS:-} ]]; then printf '%s\n' "$rows"; exit 1; fi
if [[ -n ${FAKE_ROFI_EXIT:-} ]]; then exit "$FAKE_ROFI_EXIT"; fi
if [[ -n ${FAKE_ROFI_TEXT+x} && -z $rows ]]; then printf '%s\n' "$FAKE_ROFI_TEXT"; exit 0; fi
if [[ -n ${FAKE_ROFI_INDEX:-} ]]; then printf '%s\n' "$FAKE_ROFI_INDEX"; exit 0; fi
exit 1
EOS

  chmod +x "$BIN"/*
  export PATH="$BIN:$PATH"
  export CALL_LOG FAKE_MONITORS FAKE_MONITORS_ALL FAKE_PGREP_OUT FAKE_MONITORS_SEQ
}

sandbox_reset_log() { : > "$CALL_LOG"; }

cleanup_sandbox() { [[ -n ${SANDBOX:-} && -d $SANDBOX ]] && rm -rf "$SANDBOX"; }
