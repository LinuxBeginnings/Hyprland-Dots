#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests for the display-layout user-config patches. copy.sh only ADDS missing
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
PATCH82="$PATCH_DIR/82-monitors-lua-reset.sh"
PATCH83="$PATCH_DIR/83-user-laptops-lid-open.sh"
PATCH84="$PATCH_DIR/84-user-laptops-single-monitor.sh"
PATCH85="$PATCH_DIR/85-monitor-profile-refresh-rate.sh"
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

# --- patches/82-monitors-lua-reset.sh ---------------------------------------
# The old display code wrote a generated monitors.lua on every apply, including
# the boot-time `auto`, and asked for the largest mode a monitor advertises. On a
# VM that pinned Virtual-1 to 5120x2440@50 and overrode the shipped defaults.
# This patch drops that one file, once, so an upgraded install recovers.
ML="$WORK/ml"
MARKED='-- Generated by DisplayProfile.sh - do not edit by hand.
hl.monitor({
    output = "Virtual-1",
    mode = "5120x2440@50",
    position = "0x0",
    scale = "1",
    transform = 0,
    disabled = false,
})
'

seed_ml() {  # <content>
  rm -rf "$ML"; mkdir -p "$ML/hypr/UserConfigs"
  printf '%s' "$1" >"$ML/hypr/UserConfigs/monitors.lua"
}

run_patch82() {
  env KOOLDOTS_CONFIG_HOME="$ML" KOOLDOTS_LOG="$WORK/patch82.log" bash "$PATCH82"
}

it "the reset patch removes a generated monitors.lua"
seed_ml "$MARKED"
run_patch82 >/dev/null 2>&1 || fail "the patch exited non-zero"
if [[ ! -e "$ML/hypr/UserConfigs/monitors.lua" ]]; then pass_msg
else fail "the generated file is still there"; fi

it "the reset patch keeps a backup of what it removed"
if grep -qF '5120x2440@50' "$ML/hypr/UserConfigs/"monitors.lua.generated-backup-* 2>/dev/null; then pass_msg
else fail "no backup holding the removed rules"; fi

it "the reset patch leaves a user's own monitors.lua alone"
seed_ml 'hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = "1" })
'
before="$(cat "$ML/hypr/UserConfigs/monitors.lua")"
run_patch82 >/dev/null 2>&1
assert_eq "untouched" "$before" "$(cat "$ML/hypr/UserConfigs/monitors.lua")"

it "the reset patch leaves the shipped template alone"
seed_ml "$(cat "$SCRIPT_DIR/../UserConfigs/monitors.lua")"
before="$(cat "$ML/hypr/UserConfigs/monitors.lua")"
run_patch82 >/dev/null 2>&1
assert_eq "untouched" "$before" "$(cat "$ML/hypr/UserConfigs/monitors.lua")"

it "the reset patch runs only once"
seed_ml "$MARKED"
run_patch82 >/dev/null 2>&1
# Later, the user applies a layout; it is written with the same marker and must
# not be mistaken for the stale file this patch is about.
printf '%s' "$MARKED" >"$ML/hypr/UserConfigs/monitors.lua"
run_patch82 >/dev/null 2>&1
if [[ -f "$ML/hypr/UserConfigs/monitors.lua" ]]; then pass_msg
else fail "a layout applied after the reset was deleted"; fi

mkdir -p "$WORK/ml-empty"
it "the reset patch skips when UserConfigs is not installed"
env KOOLDOTS_CONFIG_HOME="$WORK/ml-empty" KOOLDOTS_LOG="$WORK/patch82.log" \
  bash "$PATCH82" >/dev/null 2>&1 && pass_msg || fail "must exit 0"
it "the reset patch invents no config tree"
if [[ -e "$WORK/ml-empty/hypr" ]]; then fail "it created a config tree"; else pass_msg; fi

# --- patches/83-user-laptops-lid-open.sh ------------------------------------
# The lid-open branch replayed the stored rule for the panel, and a rule that
# omits `disabled` does not switch an output back on. The rules in monitors.lua
# omit it, so opening the lid left the panel dark. Only an installed
# user_laptops.lua can be reached: copy.sh protects UserConfigs.
LU="$WORK/lu"
UC83="$LU/hypr/UserConfigs/user_laptops.lua"

# The shape v2.3.27.7 shipped. The no-externals branch is the one patch 80
# leaves behind, so this is an install that has already had that fix.
seed_lid_install() {
  rm -rf "$LU"
  mkdir -p "$LU/hypr/UserConfigs"
  cat >"$UC83" <<'LUA'
local function apply_laptop_monitor_layout(trigger_refresh)
  if #externals > 0 then
    -- External display(s) connected
    if lid_closed then
      -- Clamshell / Docked mode: lid is closed, disable internal panel
      hl.monitor({ output = internal, disabled = true })
    else
      -- Lid is open: apply internal display configuration from monitors.lua
      local int_cfg = get_monitor_config(internal)
      if int_cfg then
        hl.monitor(int_cfg)
      else
        hl.monitor({
          output = internal,
          disabled = false,
          mode = default_fallback.mode or "preferred",
          position = default_fallback.position or "auto",
          scale = default_fallback.scale or "auto",
        })
      end
    end

    -- Apply configurations for external displays from monitors.lua
    for _, ext_name in ipairs(externals) do
      local cfg = get_monitor_config(ext_name)
      if cfg then
        hl.monitor(cfg)
      else
        -- Fallback if not explicitly defined in monitors.lua
        hl.monitor({
          output = ext_name,
          disabled = false,
          mode = default_fallback.mode or "preferred",
          position = default_fallback.position or "auto",
          scale = default_fallback.scale or "auto",
        })
      end
    end
  else
    -- No external displays connected
    local int_cfg = get_monitor_config(internal)
    if int_cfg then
      hl.monitor(int_cfg)
    else
      hl.monitor({ output = internal, disabled = false })
    end
  end
end
LUA
}

run_patch83() {
  env KOOLDOTS_CONFIG_HOME="$LU" KOOLDOTS_LOG="$WORK/patch83.log" bash "$PATCH83"
}

seed_lid_install
it "the lid-open patch runs cleanly on an install with the old branch"
run_patch83 && pass_msg || fail "the patch exited non-zero"

it "the lid-open branch no longer replays the stored rule as-is"
assert_not_contains "$UC83" 'Lid is open: apply internal display configuration' \
  "the branch still replays the stored rule" && pass_msg

it "the lid-open branch turns the panel back on"
assert_contains "$UC83" 'hl.monitor(int_on)' "the new call is not there"
assert_contains "$UC83" 'disabled = false,' "the forced enable is not there" && pass_msg

it "the clamshell branch keeps its lid test"
# Exactly one `disabled = true` may remain: the clamshell one.
assert_count 1 "$UC83" 'disabled = true' && pass_msg

assert_eq "the patched lid-open block is byte-identical to the repo's copy" \
  "$(sed -n '/^  if #externals > 0 then/,/^  else$/p' "$SCRIPT_DIR/../UserConfigs/user_laptops.lua")" \
  "$(sed -n '/^  if #externals > 0 then/,/^  else$/p' "$UC83")"

it "a second run changes nothing"
before="$(cat "$UC83")"
run_patch83 >/dev/null 2>&1 || fail "the second run exited non-zero"
assert_eq "the file is byte-identical after a second run" "$before" "$(cat "$UC83")"

it "the patch is applied without patch 80's no-externals fix"
# An install that never ran patch 80 still has the old no-externals branch, which
# carries a second `disabled = true` and its own `hl.monitor(int_cfg)`. It must
# still get this fix, and keep that branch exactly as it was.
seed_lid_install
awk '
  $0 == "    -- No external displays connected" { seen = 1 }
  !done && seen && $0 == "    if int_cfg then" {
    print "    if lid_closed then"
    print "      hl.monitor({ output = internal, disabled = true })"
    print "    elseif int_cfg then"
    done = 1
    next
  }
  { print }
' "$UC83" >"$UC83.pre80" && cat "$UC83.pre80" >"$UC83"
run_patch83 >/dev/null 2>&1 || fail "the patch exited non-zero"
assert_contains "$UC83" 'hl.monitor(int_on)' "the lid-open branch was not fixed"
assert_contains "$UC83" 'elseif int_cfg then' "the untouched no-externals branch was rewritten" && pass_msg

it "a customised lid-open branch is left alone"
seed_lid_install
sed -i 's/^      -- Lid is open: apply internal display configuration from monitors.lua$/      -- my own note/' "$UC83"
before="$(cat "$UC83")"
run_patch83 >/dev/null 2>&1 && pass_msg || fail "must exit 0 on a file it does not recognise"
assert_eq "the file is untouched" "$before" "$(cat "$UC83")"

mkdir -p "$WORK/lu-empty"
it "a missing user_laptops.lua is skipped cleanly"
env KOOLDOTS_CONFIG_HOME="$WORK/lu-empty" KOOLDOTS_LOG="$WORK/patch83.log" \
  bash "$PATCH83" >/dev/null 2>&1 && pass_msg || fail "must exit 0 with nothing to patch"
it "the lid-open patch invents no config tree"
if [[ -e "$WORK/lu-empty/hypr" ]]; then fail "it created a config tree"; else pass_msg; fi

# --- patches/84-user-laptops-single-monitor.sh ------------------------------
# The no-externals branch replayed the stored rule for the panel. A rule that
# omits `disabled` does not switch an output back on, and a rule carried over
# from a monitor set that had more keeps its old position - so the only screen
# could come back dark, or off the origin. The block matched here is the one
# patches/80-display-layouts.sh leaves behind.
LU84="$WORK/lu84"
UC84="$LU84/hypr/UserConfigs/user_laptops.lua"

seed_no_ext_install() {
  rm -rf "$LU84"
  mkdir -p "$LU84/hypr/UserConfigs"
  cat >"$UC84" <<'LUA'
local function apply_laptop_monitor_layout(trigger_refresh)
  if #externals > 0 then
    -- External display(s) connected
    if lid_closed then
      -- Clamshell / Docked mode: lid is closed, disable internal panel
      hl.monitor({ output = internal, disabled = true })
    else
      -- Lid is open: the internal panel has to come back ON
      local int_cfg = get_monitor_config(internal)
      local int_on = {
        output = internal,
        disabled = false,
        mode = (int_cfg and int_cfg.mode) or default_fallback.mode or "preferred",
        position = (int_cfg and int_cfg.position) or default_fallback.position or "auto",
        scale = (int_cfg and int_cfg.scale) or default_fallback.scale or "auto",
      }
      hl.monitor(int_on)
    end
  else
    -- No external displays connected: internal panel must be enabled (unless lid is closed)
    local int_cfg = get_monitor_config(internal)
    -- A shut lid with no external monitor must NOT switch the only
    -- screen off: that leaves the session with no output at all.
    if int_cfg then
      hl.monitor(int_cfg)
    else
      hl.monitor({
        output = internal,
        disabled = false,
        mode = default_fallback.mode or "preferred",
        position = "0x0",
        scale = default_fallback.scale or "auto",
      })
    end
  end
end
LUA
}

run_patch84() {
  env KOOLDOTS_CONFIG_HOME="$LU84" KOOLDOTS_LOG="$WORK/patch84.log" bash "$PATCH84"
}

seed_no_ext_install
it "the single-monitor patch runs cleanly on an install with the old branch"
run_patch84 && pass_msg || fail "the patch exited non-zero"

it "the no-externals branch no longer replays the stored rule as-is"
assert_not_contains "$UC84" 'if int_cfg then' \
  "the branch still replays the stored rule" && pass_msg

it "the no-externals branch keeps the only screen on, at the origin"
assert_contains "$UC84" 'hl.monitor(int_on)' "the new call is not there"
assert_contains "$UC84" 'position = "0x0",' "the origin pin is not there" && pass_msg

it "the clamshell branch keeps its lid test"
# Exactly one `disabled = true` may remain: the clamshell one.
assert_count 1 "$UC84" 'disabled = true' && pass_msg

it "the lid-open branch is left alone"
assert_contains "$UC84" 'Lid is open: the internal panel has to come back ON' \
  "the lid-open branch was rewritten" && pass_msg

# The file holds more than one `^  else$` and more than one `^  end$` -
# `post_layout_refresh` has both - so the block is taken from its own marker
# comment to the end of the function that holds it, rather than by line range.
no_externals_block() { # <file>
  awk '/^    -- No external displays connected/ { inblock = 1 }
       inblock { print }
       inblock && /^  end$/ { exit }' "$1"
}

assert_eq "the patched no-externals block is byte-identical to the repo's copy" \
  "$(no_externals_block "$SCRIPT_DIR/../UserConfigs/user_laptops.lua")" \
  "$(no_externals_block "$UC84")"

it "a second run changes nothing"
before="$(cat "$UC84")"
run_patch84 >/dev/null 2>&1 || fail "the second run exited non-zero"
assert_eq "the file is byte-identical after a second run" "$before" "$(cat "$UC84")"

it "a customised no-externals branch is left alone"
seed_no_ext_install
sed -i 's/^    -- No external displays connected: internal panel must be enabled (unless lid is closed)$/    -- my own note/' "$UC84"
before="$(cat "$UC84")"
run_patch84 >/dev/null 2>&1 && pass_msg || fail "must exit 0 on a file it does not recognise"
assert_eq "the file is untouched" "$before" "$(cat "$UC84")"

mkdir -p "$WORK/lu84-empty"
it "a missing user_laptops.lua is skipped cleanly"
env KOOLDOTS_CONFIG_HOME="$WORK/lu84-empty" KOOLDOTS_LOG="$WORK/patch84.log" \
  bash "$PATCH84" >/dev/null 2>&1 && pass_msg || fail "must exit 0 with nothing to patch"
it "the single-monitor patch invents no config tree"
if [[ -e "$WORK/lu84-empty/hypr" ]]; then fail "it created a config tree"; else pass_msg; fi

# --- patches/85-monitor-profile-refresh-rate.sh -----------------------------
# Monitor_Profiles/ is restored from the backup on upgrade, so a REWRITTEN
# profile never reaches an existing install - the backup's copy wins. The shipped
# high-refresh profile asked for `highrr`, which is the highest refresh rate at
# ANY resolution: on a 1920x1080@75 panel it picked 1024x768@75.03, dropping the
# resolution to chase 0.06Hz.
MP85="$WORK/mp85"
PROFILE85="$MP85/hypr/Monitor_Profiles/HDMI-A-1-HighRefreshRate.lua"

# The profile v2.3.28 shipped, byte for byte. Only a file that still matches it
# is replaced; anything else is the user's own profile.
seed_profile85() {
  rm -rf "$MP85"
  mkdir -p "$MP85/hypr/Monitor_Profiles"
  cat >"$PROFILE85" <<'LUA'
-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- HDMI-A-1 High Refresh Rate profile

hl.monitor({
    output = "HDMI-A-1",
    mode = "highrr",
    position = "auto",
    scale = "1",
})
LUA
}

run_patch85() {
  env KOOLDOTS_CONFIG_HOME="$MP85" KOOLDOTS_LOG="$WORK/patch85.log" bash "$PATCH85"
}

seed_profile85
it "the high-refresh patch runs cleanly on the profile v2.3.28 shipped"
run_patch85 && pass_msg || fail "the patch exited non-zero"

it "the profile no longer asks for highrr"
assert_not_contains "$PROFILE85" 'mode = "highrr"' "highrr is still there" && pass_msg

it "the profile asks for one mode by name instead"
assert_contains "$PROFILE85" 'mode = "1920x1080@75"' "the explicit mode is not there" && pass_msg

assert_eq "the patched profile is byte-identical to the repo's copy" \
  "$(cat "$SCRIPT_DIR/../Monitor_Profiles/HDMI-A-1-HighRefreshRate.lua")" \
  "$(cat "$PROFILE85")"

it "a second run changes nothing"
before="$(cat "$PROFILE85")"
run_patch85 >/dev/null 2>&1 || fail "the second run exited non-zero"
assert_eq "byte-identical after a second run" "$before" "$(cat "$PROFILE85")"

it "no temporary file is left beside the profile"
stray="$(find "$MP85/hypr/Monitor_Profiles" -maxdepth 1 -name '.kooldots-profile.*' 2>/dev/null)"
if [[ -n $stray ]]; then fail "left behind: $stray"; else pass_msg; fi

it "a profile the user has edited is left alone"
seed_profile85
sed -i 's/^    mode = "highrr",$/    mode = "2560x1440@144",/' "$PROFILE85"
before="$(cat "$PROFILE85")"
run_patch85 >/dev/null 2>&1 && pass_msg || fail "must exit 0 on a file it does not recognise"
assert_eq "the file is untouched" "$before" "$(cat "$PROFILE85")"

mkdir -p "$WORK/mp85-empty"
it "a missing profile is skipped cleanly"
env KOOLDOTS_CONFIG_HOME="$WORK/mp85-empty" KOOLDOTS_LOG="$WORK/patch85.log" \
  bash "$PATCH85" >/dev/null 2>&1 && pass_msg || fail "must exit 0 with nothing to patch"
it "the high-refresh patch invents no config tree"
if [[ -e "$WORK/mp85-empty/hypr" ]]; then fail "it created a config tree"; else pass_msg; fi

summary "test-display-layouts-patch"
