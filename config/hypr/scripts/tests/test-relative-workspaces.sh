#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests that a relative workspace argument stays relative. `movetoworkspace +1`
#   used to move the window to workspace 1: `workspace_value()` read "+1" with
#   `tonumber`, which is 1, and Hyprland turns a Lua number into an absolute
#   workspace selector. `hl.focus({ workspace = "+1" })` takes the same path.
#
#   Both shipped copies of the helper are loaded under a stub `hl`, so what is
#   asserted is what reaches `hl.dispatch`, not the text of a file. A plain
#   number must still arrive as a number, and `-1` must stay a string like it
#   already did.
#
#   `lua` is not a dependency of the dots, so where it is missing this reports
#   and passes instead of failing.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

# run from the repo this is config/hypr, and run from an install it is
# ~/.config/hypr, so a user's own copy is covered too.
ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SYS="$ROOT/configs/system_keybinds.lua"
HELPER="$ROOT/lua/user_keybinds_helper.lua"
MIGRATE="$SCRIPT_DIR/../../../scripts/migrate-hypr-to-lua.sh"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

if ! command -v lua >/dev/null 2>&1; then
  it "lua is not installed, so the workspace arguments were not executed"
  pass_msg
  summary "test-relative-workspaces"
  exit 0
fi

# --- syntax -----------------------------------------------------------------
it "both keybind files parse"
if command -v luac >/dev/null 2>&1; then
  if luac -p "$SYS" >/dev/null 2>&1 && luac -p "$HELPER" >/dev/null 2>&1; then
    pass_msg
  else
    fail "luac rejected system_keybinds.lua or user_keybinds_helper.lua"
  fi
else
  pass_msg
fi

# --- driver -----------------------------------------------------------------
# Prints `<name>=<value>:<type>` per case, so the shell can compare exact lines.
cat >"$WORK/driver.lua" <<'LUA'
local function record(name, value)
  print(string.format("%s=%s:%s", name, tostring(value), type(value)))
end

local function newenv()
  local env = { binds = {}, dispatched = {} }
  local function dsp(kind, t) return { kind = kind, t = t } end
  local d = {}
  d.exec_cmd = function() return dsp("exec") end
  d.exec_raw = function(s) return dsp("exec_raw", s) end
  d.no_op = function() return dsp("noop") end
  d.focus = function(t) return dsp("focus", t) end
  d.layout = function(s) return dsp("layout") end
  d.submap = function(s) return dsp("submap") end
  d.group = { toggle = function() return dsp("group") end }
  d.workspace = { toggle_special = function() return dsp("special") end }
  d.window = {
    move = function(t) return dsp("move", t) end,
    resize = function(t) return dsp("resize", t) end,
    swap = function(t) return dsp("swap", t) end,
    close = function() return dsp("close") end,
    fullscreen = function(t) return dsp("fullscreen") end,
    float = function(t) return dsp("float") end,
    pseudo = function() return dsp("pseudo") end,
    drag = function() return dsp("drag") end,
    bring_to_top = function() return dsp("top") end,
  }
  hl = {
    dsp = d,
    window = d.window,
    bind = function(chord, fn, opts)
      env.binds[#env.binds + 1] = { chord = chord, fn = fn, opts = opts }
    end,
    unbind = function() end,
    define_submap = function() end,
    dispatch = function(x) env.dispatched[#env.dispatched + 1] = x end,
    exec_cmd = function() end,
  }
  return env
end

local env = newenv()
assert(loadfile(assert(os.getenv("KOOLDOTS_TEST_SYS"))))()

-- The system binds are keyed by their description, which is what a user reads
-- in the keybind menu, so a renamed bind fails here rather than quietly.
local function press(description)
  for _, b in ipairs(env.binds) do
    if b.opts and b.opts.description == description then
      env.dispatched = {}
      b.fn()
      return env.dispatched[1]
    end
  end
  return nil
end

local function field(name, dispatched, key)
  record(name, dispatched and dispatched.t and dispatched.t[key])
end

field("sys.next", press("move to next workspace"), "workspace")
field("sys.prev", press("move to previous workspace"), "workspace")
field("sys.absolute", press("move to workspace 1"), "workspace")
field("sys.silent", press("move silently to next workspace"), "workspace")
field("sys.silent_follow", press("move silently to next workspace"), "follow")
field("sys.special", press("move to special workspace"), "workspace")
field("sys.focus", press("next workspace"), "workspace")

local henv = newenv()
local helper = assert(loadfile(assert(os.getenv("KOOLDOTS_TEST_HELPER"))))()
record("helper.plus", helper.workspace_value("+1"))
record("helper.minus", helper.workspace_value("-1"))
record("helper.plain", helper.workspace_value(" 1 "))
record("helper.mod", helper.workspace_value("m+1"))

local function user_press(name, args)
  local fn = helper.dispatch(name, args)
  henv.dispatched = {}
  fn()
  local dispatched = henv.dispatched[1]
  return dispatched and dispatched.t and dispatched.t.workspace
end

record("helper.move_next", user_press("movetoworkspace", "+1"))
record("helper.silent_prev", user_press("movetoworkspacesilent", "-1"))
record("helper.focus_next", user_press("workspace", "+1"))
LUA

OUT="$WORK/out.txt"
if env KOOLDOTS_TEST_SYS="$SYS" KOOLDOTS_TEST_HELPER="$HELPER" \
  lua "$WORK/driver.lua" >"$OUT" 2>"$WORK/err.txt"; then
  driver_ok=1
else
  driver_ok=0
fi

# --- what reaches hl.dispatch -----------------------------------------------
it "moving to the next workspace keeps the relative sign"
if (( driver_ok )); then
  assert_contains "$OUT" 'sys.next=+1:string' "movetoworkspace +1" && pass_msg
else
  fail "the lua driver failed: $(tr '\n' ';' <"$WORK/err.txt")"
fi

it "moving to the previous workspace is unchanged"
if (( driver_ok )); then
  assert_contains "$OUT" 'sys.prev=-1:string' "movetoworkspace -1" && pass_msg
else
  fail "the lua driver failed"
fi

it "an absolute workspace number still arrives as a number"
if (( driver_ok )); then
  assert_contains "$OUT" 'sys.absolute=1:number' "movetoworkspace 1" && pass_msg
else
  fail "the lua driver failed"
fi

it "the silent form keeps the sign and stays unfollowed"
if (( driver_ok )); then
  assert_contains "$OUT" 'sys.silent=+1:string' "movetoworkspacesilent +1" &&
    assert_contains "$OUT" 'sys.silent_follow=false:boolean' "follow = false" && pass_msg
else
  fail "the lua driver failed"
fi

it "a special workspace and a monitor-relative one are untouched"
if (( driver_ok )); then
  assert_contains "$OUT" 'sys.special=special:string' "special workspace" &&
    assert_contains "$OUT" 'sys.focus=m+1:string' "focus m+1" && pass_msg
else
  fail "the lua driver failed"
fi

it "the helper a user's own binds call behaves the same way"
if (( driver_ok )); then
  assert_contains "$OUT" 'helper.plus=+1:string' "workspace_value(\"+1\")" &&
    assert_contains "$OUT" 'helper.minus=-1:string' "workspace_value(\"-1\")" &&
    assert_contains "$OUT" 'helper.plain=1:number' "workspace_value(\" 1 \")" &&
    assert_contains "$OUT" 'helper.mod=m+1:string' "workspace_value(\"m+1\")" && pass_msg
else
  fail "the lua driver failed"
fi

it "the helper's dispatch keeps the sign for a user bind"
if (( driver_ok )); then
  assert_contains "$OUT" 'helper.move_next=+1:string' "dispatch('movetoworkspace', '+1')" &&
    assert_contains "$OUT" 'helper.silent_prev=-1:string' "dispatch('movetoworkspacesilent', '-1')" &&
    assert_contains "$OUT" 'helper.focus_next=+1:string' "dispatch('workspace', '+1')" && pass_msg
else
  fail "the lua driver failed"
fi

# --- migration template ------------------------------------------------------
# scripts/ is repo-side and is not installed with config/hypr, so running from
# ~/.config/hypr/scripts/tests finds nothing to test. Say so and report clean.
if [[ ! -f $MIGRATE ]]; then
  it "the migration script is not present here (repo-only check)"
  pass_msg
  summary "test-relative-workspaces"
  exit 0
fi

it "the migration template writes the same guard"
# The generator emits system_keybinds.lua on a migration, so a copy that lost
# this line would put the bug back on every install that runs it.
assert_contains "$MIGRATE" 'if value:match(\"^[+-]%d+$\") then' "the generated guard" &&
  assert_contains "$MIGRATE" '  value = trim(value)' "the generated function" && pass_msg

summary "test-relative-workspaces"
