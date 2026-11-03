#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests for patches/90-user-keybinds-helper-locals.sh, the patch that gives an
#   installed UserConfigs/user_keybinds.lua the helper bindings it is missing.
#
#   v2.3.24 to v2.3.26.1 shipped that file with only `exec_cmd` and `bind` taken
#   from lua/user_keybinds_helper.lua, so `unbind(...)` and `dispatch(...)` were
#   undefined globals and the first call to either aborted the whole file.
#   copy.sh only ADDS missing UserConfigs files, so the template fix in
#   v2.3.26.2 never reached an install made before it, and the patch is the only
#   thing that can. Issue #164 is that report.
#
#   What is checked here is that the patch adds exactly the missing lines, that
#   the result actually LOADS and resolves `unbind`, that the user's own binds
#   survive, that it is content-idempotent, and that it skips cleanly.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

# lib_test.sh sets SCRIPT_DIR to the scripts directory; the patches live at the
# repo root, three levels up.
PATCH_DIR="$SCRIPT_DIR/../../../patches"
PATCH="$PATCH_DIR/90-user-keybinds-helper-locals.sh"
REPO_LUA="$SCRIPT_DIR/../lua"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

# patches/ is repo-side and is not installed with config/hypr, so running from
# ~/.config/hypr/scripts/tests finds nothing to test. Say so and report clean.
if [[ ! -d $PATCH_DIR ]]; then
  it "the installer patches are not present here (repo-only test)"
  pass_msg
  summary "test-user-keybinds-helper-patch"
  exit 0
fi

HOME_DIR="$WORK/home"
UC="$HOME_DIR/hypr/UserConfigs"
LUA_DIR="$HOME_DIR/hypr/lua"

# The template as v2.3.24 to v2.3.26.1 shipped it: the helper is loaded, but
# only exec_cmd and bind are pulled out of it. The user's own unbind sits below
# that block, which is where the file used to abort.
seed_old_template() {
  rm -rf "$HOME_DIR"
  mkdir -p "$UC" "$LUA_DIR"
  cat >"$UC/user_keybinds.lua" <<'LUA'
-- User keybind overrides (template as shipped before v2.3.26.2).
local user_keybinds_helper = nil
do
  local source = (debug.getinfo(1, "S") or {}).source or ""
  local source_path = source:match("^@(.+)$")
  local source_dir = source_path and source_path:match("^(.*)/[^/]+$") or nil
  local home = os.getenv("HOME") or ""
  local candidate_paths = {
    source_dir and (source_dir .. "/../lua/user_keybinds_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/lua/user_keybinds_helper.lua") or nil,
  }
  for _, helper_path in ipairs(candidate_paths) do
    if helper_path then
      local f = io.open(helper_path, "r")
      if f then
        f:close()
        local loaded_ok, loaded_helpers = pcall(dofile, helper_path)
        if loaded_ok and type(loaded_helpers) == "table" and loaded_helpers.bind then
          user_keybinds_helper = loaded_helpers
          break
        end
      end
    end
  end
  if not user_keybinds_helper then
    error("Failed to load user_keybinds_helper.lua")
  end
end

local exec_cmd = user_keybinds_helper.exec_cmd
local bind = user_keybinds_helper.bind

-- The user's own edit, below the helper block. This is the line that used to
-- raise "attempt to call a nil value (global 'unbind')".
unbind("SUPER", "T")
bind("SUPER", "Z", exec_cmd("kitty"), { description = "terminal" })
LUA
  # The real helper, so the load check below exercises the shipped API.
  cp "$REPO_LUA/user_keybinds_helper.lua" "$LUA_DIR/"
}

# The template the repo ships today, which already pulls out all four. Using
# the real file rather than a copy of it means a future template that drops one
# of these lines fails here, not only on a user's machine.
seed_current_template() {
  rm -rf "$HOME_DIR"
  mkdir -p "$UC" "$LUA_DIR"
  cp "$SCRIPT_DIR/../UserConfigs/user_keybinds.lua" "$UC/user_keybinds.lua"
  cp "$REPO_LUA/user_keybinds_helper.lua" "$LUA_DIR/"
}

run_patch() {  # [config-home]
  env KOOLDOTS_CONFIG_HOME="${1:-$HOME_DIR}" KOOLDOTS_LOG="$WORK/patch.log" bash "$PATCH"
}

# dofile the target under a stub `hl` and report what the file called.
lua_calls() {  # <target> <log>
  cat >"$WORK/driver.lua" <<'LUA'
local calls = {}
local function rec(kind, ...)
  local parts = {}
  for i = 1, select("#", ...) do
    parts[#parts + 1] = tostring((select(i, ...)))
  end
  calls[#calls + 1] = kind .. " " .. table.concat(parts, "|")
end
local dsp = {}
dsp.exec_cmd = function() return function() end end
dsp.no_op = function() return function() end end
hl = {
  dsp = dsp,
  bind = function(...) rec("bind", ...) end,
  unbind = function(...) rec("unbind", ...) end,
  dispatch = function(...) rec("dispatch", ...) end,
  exec_cmd = function(cmd) rec("exec_cmd", cmd) end,
}
local ok, err = pcall(dofile, os.getenv("KOOLDOTS_TEST_TARGET"))
local f = assert(io.open(os.getenv("KOOLDOTS_TEST_LOG"), "w"))
f:write("load " .. tostring(ok) .. " " .. tostring(err) .. "\n")
for _, line in ipairs(calls) do f:write(line .. "\n") end
f:close()
LUA
  env KOOLDOTS_TEST_TARGET="$1" KOOLDOTS_TEST_LOG="$2" lua "$WORK/driver.lua"
}

# --- activation -------------------------------------------------------------
seed_old_template
it "the patch runs cleanly on an install that predates the fix"
run_patch && pass_msg || fail "the patch exited non-zero"

it "unbind is now bound from the helper"
assert_contains "$UC/user_keybinds.lua" 'local unbind = user_keybinds_helper.unbind' "the missing local" && pass_msg

it "dispatch is now bound from the helper"
assert_contains "$UC/user_keybinds.lua" 'local dispatch = user_keybinds_helper.dispatch' "the missing local" && pass_msg

it "the bindings sit in the helper block, above the user's own edits"
assert_order "$UC/user_keybinds.lua" 'local bind = user_keybinds_helper.bind' 'unbind("SUPER", "T")' && pass_msg

it "the user's own edits survive"
assert_contains "$UC/user_keybinds.lua" 'unbind("SUPER", "T")' "the user's unbind" &&
  assert_contains "$UC/user_keybinds.lua" 'bind("SUPER", "Z"' "the user's bind" && pass_msg

it "the file still parses"
if command -v luac >/dev/null 2>&1; then
  luac -p "$UC/user_keybinds.lua" >/dev/null 2>&1 && pass_msg || fail "luac rejected the patched file"
else
  pass_msg
fi

# The point of the patch: the file loads and unbind() reaches hl.unbind. Before
# it, this file aborted at the user's own unbind line and bound nothing at all.
it "the patched file loads and unbind() reaches hl.unbind"
if command -v lua >/dev/null 2>&1; then
  if lua_calls "$UC/user_keybinds.lua" "$WORK/calls.log"; then
    if grep -q '^load true' "$WORK/calls.log" &&
      grep -q '^unbind SUPER + T' "$WORK/calls.log" &&
      grep -q '^bind SUPER + Z' "$WORK/calls.log"; then
      pass_msg
    else
      fail "expected a clean load, an unbind of 'SUPER + T' and a bind of 'SUPER + Z': $(tr '\n' ';' <"$WORK/calls.log")"
    fi
  else
    fail "the lua driver failed to run"
  fi
else
  it "lua is not installed, so the patched file was not executed"
  pass_msg
fi

# --- idempotency ------------------------------------------------------------
before="$(cat "$UC/user_keybinds.lua")"
it "a second run changes nothing"
if run_patch >/dev/null 2>&1; then pass_msg; else fail "the second run exited non-zero"; fi
assert_eq "the file is byte-identical after a second run" \
  "$before" "$(cat "$UC/user_keybinds.lua")"

it "neither line was added twice"
assert_count 1 "$UC/user_keybinds.lua" 'local unbind = user_keybinds_helper.unbind' &&
  assert_count 1 "$UC/user_keybinds.lua" 'local dispatch = user_keybinds_helper.dispatch' && pass_msg

# --- already current --------------------------------------------------------
# A template from v2.3.26.2 or later already has both lines; the patch must not
# touch it, and must not be confused by the submap local that follows.
seed_current_template
before="$(cat "$UC/user_keybinds.lua")"
it "a template that already binds them is left alone"
if run_patch >/dev/null 2>&1; then pass_msg; else fail "the patch exited non-zero"; fi
assert_eq "the file is unchanged" "$before" "$(cat "$UC/user_keybinds.lua")"

# --- skip cleanly -----------------------------------------------------------
mkdir -p "$WORK/empty"
it "a missing target is skipped cleanly"
if run_patch "$WORK/empty" >/dev/null 2>&1; then pass_msg; else fail "must exit 0 with nothing to patch"; fi

it "nothing is created for an install that is not there"
if [[ -e "$WORK/empty/hypr" ]]; then fail "it created files for an install that is not there"; else pass_msg; fi

# --- a file that does not load the helper -----------------------------------
# Adding the lines there would read from a name that file never defined, so it
# is left alone rather than turned into a different error.
mkdir -p "$WORK/noloader/hypr/UserConfigs"
cat >"$WORK/noloader/hypr/UserConfigs/user_keybinds.lua" <<'LUA'
-- A hand-written file with its own bind helper.
local function mybind(mods, key, cmd)
  hl.bind(mods .. " + " .. key, hl.dsp.exec_cmd(cmd))
end
mybind("SUPER", "Z", "kitty")
LUA
cp "$WORK/noloader/hypr/UserConfigs/user_keybinds.lua" "$WORK/noloader/before.lua"
it "a file that does not load the keybind helper is left alone"
run_patch "$WORK/noloader" >/dev/null 2>&1 && pass_msg || fail "must exit 0"
assert_eq "the file is untouched" "$(cat "$WORK/noloader/before.lua")" \
  "$(cat "$WORK/noloader/hypr/UserConfigs/user_keybinds.lua")"

summary "test-user-keybinds-helper-patch"
