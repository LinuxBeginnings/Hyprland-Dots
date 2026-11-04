#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   The three app helpers in scripts/lib_apps.sh add one command each to
#   UserConfigs/user_startup.lua. They used to insert it with an UNANCHORED
#
#     sed '/local startup_commands = {/a \  "ags",'
#
#   Every template before v2.3.28 ships the startup block commented out, so that
#   address matched `-- local startup_commands = {` and put the entry outside any
#   table. The file stopped parsing, lua/user_overrides.lua dropped it with a
#   single [WARN], and every startup command in it silently stopped running.
#
#   What is checked here is that the helpers can no longer produce that shape, on
#   either template, that they are content-idempotent, and that
#   patches/91-user-startup-orphan-entry.sh repairs a file the old code already
#   broke. The broken fixture is generated with the OLD command itself, so the
#   regression it stands for is the real one.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

# lib_test.sh sets SCRIPT_DIR to the scripts directory; the installer helpers and
# the patches live at the repo root, three levels up.
REPO_SCRIPTS="$SCRIPT_DIR/../../../scripts"
REPO_ROOT="$SCRIPT_DIR/../../.."
PATCH="$SCRIPT_DIR/../../../patches/91-user-startup-orphan-entry.sh"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

# The suite is installed with the rest of config/hypr, but lib_apps.sh and
# patches/ are repo-side and only the installer runs them. Running from
# ~/.config/hypr/scripts/tests therefore finds neither, so say so and report
# clean instead of failing every check.
if [ ! -f "$REPO_SCRIPTS/lib_apps.sh" ] || [ ! -f "$PATCH" ]; then
  it "the installer helpers are not present here (repo-only test)"
  pass_msg
  summary "test-user-startup-entries"
  exit 0
fi

# shellcheck source=../../../scripts/lib_apps.sh
source "$REPO_SCRIPTS/lib_apps.sh"

# The helpers gate on `command -v`, so the three applications are faked onto
# PATH. enable_ags() also seds the Refresh scripts under $DOTFILES_DIR, which is
# pointed at a throwaway tree so a test run cannot touch the repo.
BIN="$WORK/bin"
mkdir -p "$BIN"
for cmd in ags asusctl blueman-applet; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$BIN/$cmd"
done
chmod +x "$BIN"/*
export PATH="$BIN:$PATH"

export DOTFILES_DIR="$WORK/dotfiles"
mkdir -p "$DOTFILES_DIR/config/hypr/scripts"

export XDG_CONFIG_HOME="$WORK/cfg"
UC="$XDG_CONFIG_HOME/hypr/UserConfigs"
LOG="$WORK/copy.log"
mkdir -p "$UC"
TARGET="$UC/user_startup.lua"

HAVE_LUAC=0
command -v luac >/dev/null 2>&1 && HAVE_LUAC=1

LIVE_TABLE='^[[:space:]]*local[[:space:]]+startup_commands[[:space:]]*=[[:space:]]*[{]'
LIVE_ENTRY='^[[:space:]]*"[^"]*",[[:space:]]*$'

# parses <file>: a real parse where luac is installed, and a pass where it is not
# (it is not a dependency of the dots; test-lua-syntax.sh reports and passes the
# same way).
parses() {
  [ "$HAVE_LUAC" -eq 1 ] || return 0
  luac -p "$1" >/dev/null 2>&1
}

# no_orphan <file>: no live entry line unless a live table can hold it. This is
# the invariant, and unlike the parse check it needs no external tool.
no_orphan() {
  grep -qE "$LIVE_TABLE" "$1" && return 0
  ! grep -qE "$LIVE_ENTRY" "$1"
}

# entry_inside_table <file> <entry>: the entry is after the table's opening line
# and before its closing brace.
entry_inside_table() {
  awk -v want="$2" '
    /^[[:space:]]*local[[:space:]]+startup_commands[[:space:]]*=[[:space:]]*[{]/ { intable = 1; next }
    intable && /^[[:space:]]*}/ { intable = 0 }
    intable && index($0, want) { found = 1 }
    END { exit (found ? 0 : 1) }
  ' "$1"
}

# The shipped shape: a live table with the examples commented out.
seed_current_template() {
  rm -f "$TARGET"
  cat >"$TARGET" <<'LUA'
-- User startup overrides template.
local user_startup_helper = nil
local exec_once = function(cmd) end

-- Add custom startup commands:
local startup_commands = {
  -- "kdeconnect-app",
  -- "blueman-applet",
  -- "$HOME/.config/hypr/UserScripts/RainbowBorders.sh",
  "$HOME/.config/hypr/scripts/MonitorWatcher.sh",
}

local function run_startup_commands()
  for _, cmd in ipairs(startup_commands) do
    exec_once(cmd)
  end
end
LUA
}

# The shape every template before v2.3.28 ships: the whole block commented out,
# including the example exec_once("blueman-applet") the guards used to read as
# "blueman is already enabled".
seed_old_template() {
  rm -f "$TARGET"
  cat >"$TARGET" <<'LUA'
-- User startup overrides template.
local user_startup_helper = nil
local exec_once = function(cmd) end

-- Examples:
-- exec_once("blueman-applet")
--
-- Template (uncomment and edit):
-- local startup_commands = {
--   "nm-applet",
--   "$HOME/.config/hypr/UserScripts/my-startup-script.sh",
-- }
--
-- for _, cmd in ipairs(startup_commands) do
--   exec_once(cmd)
-- end
LUA
}

# What the old installer left behind, produced by the old command itself.
break_like_old_installer() {  # <command>
  sed -i "/local startup_commands = {/a \\  \"$1\"," "$TARGET"
}

it "the current template parses and has no orphan"
seed_current_template
if parses "$TARGET" && no_orphan "$TARGET"; then pass_msg; else fail "the fixture itself is broken"; fi

# --- the helpers on the current template ------------------------------------
it "enable_ags adds the entry inside the live table"
enable_ags "$LOG"
entry_inside_table "$TARGET" '"ags",' && pass_msg || fail "the entry is not inside the table"

it "the file still parses and has no orphan"
if parses "$TARGET" && no_orphan "$TARGET"; then pass_msg
else fail "enable_ags produced a file that does not parse or has an orphan"; fi

it "a second enable_ags adds nothing"
before="$(cat "$TARGET")"
enable_ags "$LOG" >/dev/null 2>&1
assert_eq "byte-identical after a second run" "$before" "$(cat "$TARGET")"

it "enable_blueman uncomments the shipped entry instead of adding a second"
enable_blueman "$LOG"
assert_count 1 "$TARGET" '"blueman-applet",' && pass_msg
it "the uncommented entry is a live one, inside the table"
entry_inside_table "$TARGET" '"blueman-applet",' && pass_msg || fail "the entry is not inside the table"
it "the file still parses after enable_blueman"
if parses "$TARGET" && no_orphan "$TARGET"; then pass_msg; else fail "enable_blueman broke the file"; fi

# --- the helpers on the old, commented template -----------------------------
# This is the case the bug was reported on: the table is commented out, so an
# insert after that line lands outside any table.
it "enable_ags on the commented template does not write an entry outside a table"
seed_old_template
enable_ags "$LOG" >/dev/null 2>&1
no_orphan "$TARGET" && pass_msg || fail "an entry line was written outside a table"

it "the file still parses"
if parses "$TARGET"; then pass_msg; else fail "enable_ags broke the commented template"; fi

it "the command is added as a live exec_once() call instead"
assert_contains "$TARGET" 'exec_once("ags")' "the fallback entry" && pass_msg

it "a second enable_ags on the commented template adds nothing"
before="$(cat "$TARGET")"
enable_ags "$LOG" >/dev/null 2>&1
assert_eq "byte-identical after a second run" "$before" "$(cat "$TARGET")"

it "enable_asusctl takes the same fallback and keeps the file valid"
seed_old_template
enable_asusctl "$LOG" >/dev/null 2>&1
if parses "$TARGET" && no_orphan "$TARGET" &&
  grep -qF 'exec_once("rog-control-center")' "$TARGET"; then pass_msg
else fail "enable_asusctl did not add a valid live entry"; fi

it "enable_blueman on the commented template does not uncomment the example"
seed_old_template
enable_blueman "$LOG" >/dev/null 2>&1
if parses "$TARGET" && no_orphan "$TARGET"; then pass_msg
else fail "enable_blueman produced an orphan on the commented template"; fi

# --- the repair patch -------------------------------------------------------
it "the old installer's insert really does break the file"
seed_old_template
break_like_old_installer ags
if grep -qE "$LIVE_ENTRY" "$TARGET"; then pass_msg; else fail "the fixture has no orphan to repair"; fi

it "and that broken file does not parse"
if [ "$HAVE_LUAC" -eq 1 ]; then
  if parses "$TARGET"; then fail "luac accepted the file the old installer produced"
  else pass_msg; fi
else
  pass_msg
fi

run_patch() {
  env KOOLDOTS_CONFIG_HOME="$XDG_CONFIG_HOME" KOOLDOTS_LOG="$WORK/patch.log" bash "$PATCH"
}

it "the patch runs cleanly on the broken file"
run_patch >/dev/null 2>&1 && pass_msg || fail "the patch exited non-zero"

it "the orphan is commented out"
assert_contains "$TARGET" '--   "ags",' "the orphan is commented" && pass_msg

it "no live entry line is left outside a table"
no_orphan "$TARGET" && pass_msg || fail "an orphan survived the repair"

it "the repaired file parses"
if parses "$TARGET"; then pass_msg; else fail "the repaired file still does not parse"; fi

it "the patch is content-idempotent"
before="$(cat "$TARGET")"
run_patch >/dev/null 2>&1 || fail "the second run exited non-zero"
assert_eq "byte-identical after a second run" "$before" "$(cat "$TARGET")"

it "the next upgrade adds the command back, as a live entry"
enable_ags "$LOG" >/dev/null 2>&1
if grep -qF 'exec_once("ags")' "$TARGET" && parses "$TARGET" && no_orphan "$TARGET"; then pass_msg
else fail "enable_ags did not add the repaired file's entry back"; fi

it "a file with a live table is left alone by the patch"
seed_current_template
before="$(cat "$TARGET")"
run_patch >/dev/null 2>&1 || fail "the patch exited non-zero"
assert_eq "the file is unchanged" "$before" "$(cat "$TARGET")"

it "a file with no orphan is left alone"
seed_old_template
before="$(cat "$TARGET")"
run_patch >/dev/null 2>&1 || fail "the patch exited non-zero"
assert_eq "the file is unchanged" "$before" "$(cat "$TARGET")"

it "a missing target is skipped cleanly"
mkdir -p "$WORK/empty"
if env KOOLDOTS_CONFIG_HOME="$WORK/empty" KOOLDOTS_LOG="$WORK/patch.log" bash "$PATCH" >/dev/null 2>&1; then pass_msg
else fail "must exit 0 with nothing to repair"; fi

it "nothing is created for an install that is not there"
if [ -e "$WORK/empty/hypr" ]; then fail "it created files for an install that is not there"; else pass_msg; fi

summary "test-user-startup-entries"
