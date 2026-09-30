-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- Shared startup helper. Loaded by both startup lists:
--   * config/hypr/configs/system_startup.lua -> lua/startup.lua
--   * UserConfigs/user_startup.lua
-- Both call the exec_once() below, so the two lists cannot drift apart.
-- The name is kept for compatibility: UserConfigs/user_startup.lua resolves it
-- by path, so renaming it would break existing installs.

local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

-- Readiness gate, prepended to every startup command.
--
-- Two independent waits, both bounded:
--   1. Wayland socket. WAYLAND_DISPLAY is not guaranteed to be set in the
--      environment Hyprland itself was started with, so scan the runtime dir
--      when it is missing or stale.
--   2. Hyprland IPC with at least one output. The socket file appears as soon
--      as the compositor creates its display, well before it has finished
--      coming up, so "the socket exists" is not a usable readiness signal.
--      Clients launched in that window initialise against a compositor with no
--      outputs yet, which is why scripts/WallpaperDaemon.sh polls for monitors
--      for up to 12s before it touches anything. Waiting on `hyprctl -j
--      monitors` until it reports a monitor replaces the ad-hoc `sleep N` that
--      startup commands needed to work around this.
local READINESS = [[runtime=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}; export XDG_RUNTIME_DIR="$runtime"; i=0; while [ "$i" -lt 60 ]; do if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "$runtime/$WAYLAND_DISPLAY" ]; then break; fi; for sock in "$runtime"/wayland-[0-9]*; do [ -S "$sock" ] || continue; case "$(basename "$sock")" in *awww*) continue ;; esac; export WAYLAND_DISPLAY="$(basename "$sock")"; break; done; i=$((i + 1)); sleep 0.1; done; if command -v hyprctl >/dev/null 2>&1; then i=0; while [ "$i" -lt 100 ]; do hyprctl -j monitors 2>/dev/null | grep -q '"name"' && break; i=$((i + 1)); sleep 0.1; done; fi]]

local function exec_once(cmd, opts)
  -- Why this wrapper exists:
  -- 1) Enforce once-per-Hypr-session startup behavior using marker files.
  -- 2) Wait for a usable session before the command runs (see READINESS).
  -- 3) Capture per-command logs to simplify troubleshooting in user setups.

  opts = opts or {}
  local session = opts.session or os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "default"
  local marker_prefix = opts.marker_prefix or "/tmp/hypr-lua-user-exec-once-"
  local log_prefix = opts.log_prefix or "/tmp/hypr-lua-user-startup-"

  local key = cmd:gsub("[^%w_.-]", "_"):sub(1, 80)
  local marker = marker_prefix .. session .. "-" .. key
  local log = log_prefix .. key .. ".log"

  local inner = READINESS .. "; " .. cmd
  local wrapper = "[ -e " .. shell_quote(marker) .. " ] || { touch " .. shell_quote(marker)
    .. " && sh -c " .. shell_quote(inner) .. " >>" .. shell_quote(log) .. " 2>&1 & }"

  -- Spawn through the compositor whenever the runtime offers it.
  --
  -- os.execute() forks from the Hyprland process itself, so the command
  -- inherits Hyprland's environment and blocked signal mask, stays inside
  -- Hyprland's session/process group, and runs from a login shell. That is a
  -- different contract from the native `exec-once` these lists replaced, and
  -- GUI clients, tray applets and D-Bus services notice: they are the ones that
  -- needed `sleep N` prepended to work at all.
  --
  -- hl.exec_cmd() is the same spawn path the native `exec-once` used - session
  -- environment, reset signal mask, own session - and is already how keybinds,
  -- user_laptops.lua and screenshot-region.lua launch programs. Hyprland runs
  -- the command through `sh -c`, so the marker/readiness/log wrapper above is
  -- still honoured.
  if hl and hl.exec_cmd then
    hl.exec_cmd(wrapper)
    return
  end

  -- Fallback for runtimes without the exec_cmd binding.
  os.execute("sh -c " .. shell_quote(wrapper))
end

return {
  exec_once = exec_once,
}
