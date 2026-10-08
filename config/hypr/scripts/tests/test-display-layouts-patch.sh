#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests for patches/80-display-layouts.sh. copy.sh only ADDS missing
#   UserConfigs files, so on an install that already has them the patch is the
#   ONLY thing that activates the display-layout feature. What is checked here
#   is that it activates it, that it does not touch the parts of the files it
#   has no business touching, that it is content-idempotent, and that it skips
#   cleanly when there is nothing to patch.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

# lib_test.sh sets SCRIPT_DIR to the scripts directory; the patches live at the
# repo root, three levels up.
PATCH_DIR="$SCRIPT_DIR/../../../patches"
PATCH="$PATCH_DIR/80-display-layouts.sh"
PATCH81="$PATCH_DIR/81-monitor-profiles-readme.sh"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

# The suite is installed with the rest of config/hypr, but the patches it tests
# are not: patches/ is repo-side, and the installer runs them from there. Running
# from ~/.config/hypr/scripts/tests therefore finds no patches, so say so and
# report clean instead of failing every check.
if [[ ! -d $PATCH_DIR ]]; then
  it "the installer patches are not present here (repo-only test)"
  pass_msg
  summary "test-display-layouts-patch"
  exit 0
fi
HOME_DIR="$WORK/home"

# An install that predates the display-layout system: the templates as they
# were, with no watcher line, no display binds and the old lid branch.
seed_install() {
  rm -rf "$HOME_DIR"
  mkdir -p "$HOME_DIR/hypr/UserConfigs"
  cat >"$HOME_DIR/hypr/UserConfigs/user_startup.lua" <<'LUA'
-- user startup template
local startup_commands = {
  -- "kdeconnect-app",
}

local function run_startup_commands()
  for _, cmd in ipairs(startup_commands) do
    exec_once(cmd)
  end
end
LUA
  cat >"$HOME_DIR/hypr/UserConfigs/user_keybinds.lua" <<'LUA'
-- user keybinds template
bind("SUPER", "Q", exec_cmd("kitty"), { description = "terminal" })
LUA
  # Both branches carry the same two lines; only the second one has
  # `elseif int_cfg then` after them, and only that one may be changed.
  cat >"$HOME_DIR/hypr/UserConfigs/user_laptops.lua" <<'LUA'
local function apply_laptop_monitor_layout()
  if #externals > 0 then
    if lid_closed then
      -- Clamshell / Docked mode
      hl.monitor({ output = internal, disabled = true })
    else
      hl.monitor(int_cfg)
    end
  else
    local int_cfg = get_monitor_config(internal)
    if lid_closed then
      hl.monitor({ output = internal, disabled = true })
    elseif int_cfg then
      hl.monitor(int_cfg)
    else
      hl.monitor({ output = internal, disabled = false })
    end
  end
end
LUA
}

run_patch() {  # [config-home]
  env KOOLDOTS_CONFIG_HOME="${1:-$HOME_DIR}" KOOLDOTS_LOG="$WORK/patch.log" bash "$PATCH"
}

UC="$HOME_DIR/hypr/UserConfigs"

# --- activation -------------------------------------------------------------
seed_install
it "the patch runs cleanly on an install that predates the feature"
run_patch && pass_msg || fail "the patch exited non-zero"

it "user_startup.lua now starts MonitorWatcher.sh"
assert_contains "$UC/user_startup.lua" 'MonitorWatcher.sh' "the watcher is started" && pass_msg

it "the watcher line is inside the startup_commands table"
# Inside means: after the table's opening line and before its closing brace.
awk '/^local startup_commands = \{/ { intable = 1; next }
     intable && /^\}/ { intable = 0 }
     intable && /MonitorWatcher\.sh/ { found = 1 }
     END { exit (found ? 0 : 1) }' "$UC/user_startup.lua" \
  && pass_msg || fail "the watcher line is not inside the table"

it "the rest of user_startup.lua is untouched"
assert_contains "$UC/user_startup.lua" 'run_startup_commands' "the existing helper survives" && pass_msg

it "user_keybinds.lua now binds the layout menu and the Work layout"
assert_contains "$UC/user_keybinds.lua" 'DisplayProfileMenu.sh' "the menu bind is added"
assert_contains "$UC/user_keybinds.lua" 'DisplayProfile.sh -- Work' "the Work bind is added"
assert_contains "$UC/user_keybinds.lua" 'bind("SUPER", "Q"' "the user's own bind survives" && pass_msg

it "the no-externals branch no longer switches off the only screen"
if grep -q 'elseif int_cfg then' "$UC/user_laptops.lua"; then
  fail "the branch still disables the internal panel when the lid is shut"
else pass_msg; fi

it "the clamshell branch keeps its lid test"
# Exactly one `disabled = true` may remain: the clamshell one. Zero would mean
# the patch removed both, two would mean it removed neither.
assert_count 1 "$UC/user_laptops.lua" 'disabled = true' && pass_msg

it "an empty layout store is created when there was none"
[[ -f "$UC/display-layouts.json" ]] && pass_msg || fail "no store was created"
assert_json_eq "$UC/display-layouts.json" '.version' '1'
assert_json_eq "$UC/display-layouts.json" '.fingerprints | length' '0'

# --- idempotency ------------------------------------------------------------
before="$(cat "$UC/user_startup.lua" "$UC/user_keybinds.lua" "$UC/user_laptops.lua")"
it "a second run changes nothing"
run_patch >/dev/null 2>&1 || fail "the second run exited non-zero"
assert_eq "the files are byte-identical after a second run" \
  "$before" "$(cat "$UC/user_startup.lua" "$UC/user_keybinds.lua" "$UC/user_laptops.lua")"

it "the keybinds were not appended twice"
assert_count 1 "$UC/user_keybinds.lua" 'DisplayProfileMenu.sh' && pass_msg
it "the watcher line was not added twice"
assert_count 1 "$UC/user_startup.lua" 'MonitorWatcher.sh' && pass_msg

# --- skip cleanly -----------------------------------------------------------
mkdir -p "$WORK/empty"
it "a missing target is skipped cleanly"
run_patch "$WORK/empty" >/dev/null 2>&1 && pass_msg || fail "must exit 0 with nothing to patch"
if [[ -e "$WORK/empty/hypr" ]]; then fail "it created files for an install that is not there"; else pass_msg; fi

it "an existing store is never overwritten"
printf '{"version":1,"fingerprints":{"x":{}}}\n' >"$UC/display-layouts.json"
run_patch >/dev/null 2>&1
assert_json_eq "$UC/display-layouts.json" '.fingerprints | length' '1'

# --- a startup table that is not on its own line ----------------------------
it "a collapsed startup table is left alone rather than corrupted"
mkdir -p "$WORK/odd/hypr/UserConfigs"
printf 'local startup_commands = {}\n' >"$WORK/odd/hypr/UserConfigs/user_startup.lua"
cp "$WORK/odd/hypr/UserConfigs/user_startup.lua" "$WORK/odd/before.lua"
run_patch "$WORK/odd" >/dev/null 2>&1 && pass_msg || fail "must exit 0"
assert_eq "the file is untouched" "$(cat "$WORK/odd/before.lua")" \
  "$(cat "$WORK/odd/hypr/UserConfigs/user_startup.lua")"

# --- patches/81-monitor-profiles-readme.sh ----------------------------------
# Monitor_Profiles/ is restored from the backup on upgrade, so a REWRITTEN README
# in it never reaches an existing install - the backup's copy wins. This patch
# APPENDS a note instead, and must never lose what a user already wrote there.
MP="$WORK/mp"
MP_README="$MP/hypr/Monitor_Profiles/README"
OLD_README='# Create a Monitor profile you want to on this directory
# tip: You can easily create a profile using nwg-displays
'

seed_readme() {  # <content>
  rm -rf "$MP"; mkdir -p "$MP/hypr/Monitor_Profiles"
  printf '%s' "$1" >"$MP_README"
}

run_patch81() {
  env KOOLDOTS_CONFIG_HOME="$MP" KOOLDOTS_LOG="$WORK/patch81.log" bash "$PATCH81"
}

it "the README patch appends the current notes without dropping the old text"
seed_readme "$OLD_README"
run_patch81 >/dev/null 2>&1 || fail "the patch exited non-zero"
if grep -qF 'Create a Monitor profile you want' "$MP_README" \
   && grep -qF 'Managed by the display-layout system' "$MP_README"; then pass_msg
else fail "expected both the old text and the new note"; fi

it "the README patch is idempotent"
before="$(cat "$MP_README")"
run_patch81 >/dev/null 2>&1
assert_eq "byte-identical after a second run" "$before" "$(cat "$MP_README")"

it "the README patch keeps a user's own notes and still adds the note"
seed_readme '# Create a Monitor profile you want to on this directory
# MY OWN NOTES: do not delete
'
run_patch81 >/dev/null 2>&1
if grep -qF 'MY OWN NOTES' "$MP_README" \
   && grep -qF 'Managed by the display-layout system' "$MP_README"; then pass_msg
else fail "expected their text to survive and the note to be added"; fi

it "the README patch leaves the repo's own copy alone"
seed_readme "$(cat "$SCRIPT_DIR/../Monitor_Profiles/README")"
before="$(cat "$MP_README")"
run_patch81 >/dev/null 2>&1
assert_eq "untouched" "$before" "$(cat "$MP_README")"

it "the README patch skips when there is nothing to patch"
rm -rf "$MP"; mkdir -p "$MP"
run_patch81 >/dev/null 2>&1 && pass_msg || fail "must exit 0 with no README"

summary "test-display-layouts-patch"
