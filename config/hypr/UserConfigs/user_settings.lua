-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================
-- User settings overrides template.
-- Use this file to configure input, cursor, layouts (dwindle/master), window focus, and rendering.
-- Sourced by lua/user_overrides.lua.
--
-- =============================================================================
-- SETTINGS CATEGORIES & EXAMPLES (KoolDots Lua)
-- =============================================================================

-- 1. KEYBOARD & INPUT SETTINGS:
hl.config({
  input = {
    kb_layout = "us",                        -- Keyboard layout (e.g. "us", "de", "es", "fr", "ru")
    kb_variant = "",                         -- Keyboard variant (e.g. "dvorak", "colemak")
    kb_model = "pc105",                      -- Keyboard model
    kb_options = "",                         -- e.g. "caps:swapescape", "grp:alt_shift_toggle"
    kb_rules = "",
    repeat_rate = 50,                        -- Key repeat rate in characters per second
    repeat_delay = 300,                      -- Delay before repeating in ms
    sensitivity = 0,                         -- Mouse sensitivity (-1.0 to 1.0)
    accel_profile = "",                      -- Mouse acceleration: "flat", "adaptive", or ""
    numlock_by_default = true,               -- Enable NumLock on startup
    left_handed = false,                     -- Swap left and right mouse buttons
    follow_mouse = 1,                        -- 0=click to focus, 1=cursor focus, 2=loose focus, 3=detach focus
    float_switch_override_focus = false,     -- Focus behavior when switching between tiled and floating
    touchpad = {
      disable_while_typing = true,           -- Prevent accidental touchpad palm taps while typing
      natural_scroll = true,                 -- Reverse / natural scroll direction
      clickfinger_behavior = false,          -- 1 finger=left click, 2=right click, 3=middle click
      middle_button_emulation = false,       -- Click left+right simultaneously for middle click
      tap_to_click = true,                   -- Enable tap to click on touchpad
      drag_lock = false,                     -- Hold drag after releasing finger
    },
    touchdevice = {
      enabled = true,
    },
    tablet = {
      transform = 0,
      left_handed = 0,
    },
  },
})

-- 2. CURSOR & POINTER BEHAVIOR:
-- hl.config({
--   cursor = {
--     no_warps = true,                       -- Don't warp cursor to window center on focus changes
--     warp_on_change_workspace = 2,          -- 0=don't warp, 1=warp to center, 2=warp to last active window
--     inactive_timeout = 0,                  -- Hide cursor after X seconds of inactivity (0 = never)
--     hide_on_key_press = true,              -- Hide cursor when typing text
--     hide_on_touch = false,                 -- Hide cursor on touchscreen events
--     default_monitor = "",                  -- Default monitor to position cursor on startup
--     zoom_factor = 1.0,                     -- Desktop zoom magnification factor
--     zoom_rigid = false,                    -- Smooth zoom transitions
--     no_hardware_cursors = 0,               -- 0=hardware cursor (fast), 1=software (useful for VM/recording)
--     enable_hyprcursor = true,              -- Enable modern Hyprcursor theme engine
--     sync_gsettings_theme = true,           -- Keep cursor theme synchronized with GTK
--   },
-- })

-- 3. DWINDLE LAYOUT SETTINGS:
-- hl.config({
--   dwindle = {
--     preserve_split = true,                 -- Keep split orientation when closing sibling windows
--     smart_split = false,                   -- Automatically choose split direction based on cursor position
--     smart_resizing = true,                 -- Resize adjoining windows when resizing a split
--     use_active_for_splits = true,          -- Split active window instead of window under cursor
--     default_split_ratio = 1.0,             -- 1.0 = equal 50/50 splits
--     split_bias = 0,                        -- 0=no bias, 1=prefer top/left, 2=prefer bottom/right
--     special_scale_factor = 0.8,            -- Scale factor for windows in scratchpads
--   },
-- })

-- 4. MASTER LAYOUT SETTINGS:
-- hl.config({
--   master = {
--     new_status = "slave",                  -- "master" (new window is master) or "slave"
--     new_on_top = false,                    -- Place new window at top of stack
--     orientation = "left",                  -- Master position: "left", "right", "top", "bottom", "center"
--     mfact = 0.55,                          -- Master window width ratio (0.1 to 0.9)
--     slave_count_for_center_master = 2,     -- Slaves required on each side for center master
--     smart_resizing = true,
--     drop_at_cursor = true,
--   },
-- })

-- 5. MISCELLANEOUS & COMPOSITOR BEHAVIOR:
-- hl.config({
--   misc = {
--     vrr = 0,                               -- Adaptive sync / G-Sync: 0=disabled, 1=always on, 2=fullscreen only
--     mouse_move_enables_dpms = true,        -- Wake monitors from sleep on mouse movement
--     key_press_enables_dpms = true,         -- Wake monitors from sleep on key press
--     disable_hyprland_logo = true,          -- Disable default anime wallpaper / logo
--     disable_splash_rendering = true,       -- Disable startup splash text
--     focus_on_activate = false,             -- Refuse focus requests from applications on startup
--     initial_workspace_tracking = 0,        -- Track which workspace spawned an app
--     middle_click_paste = false,            -- Disable middle click paste from primary selection
--     enable_anr_dialog = true,              -- Show "Application Not Responding" dialog
--     enable_swallow = true,                 -- Swallow terminal window when launching GUI app from CLI
--     swallow_regex = "^(kitty|ghostty)$",   -- Terminal classes to swallow
--   },
-- })

-- 6. XWAYLAND & COMPATIBILITY:
-- hl.config({
--   xwayland = {
--     enabled = true,
--     force_zero_scaling = true,             -- Fix blurry XWayland apps when fractional scaling is active
--     use_nearest_neighbor = false,          -- Scaling interpolation filter
--   },
-- })

-- 7. KEYBIND & WORKSPACE NAVIGATION RULES:
-- hl.config({
--   binds = {
--     workspace_back_and_forth = true,       -- Switching to current workspace returns to previous
--     allow_workspace_cycles = true,         -- Enable previous workspace cycling
--     pass_mouse_when_bound = false,         -- Forward mouse clicks to apps even if bound
--     workspace_center_on = 1,               -- Center cursor when switching workspaces
--   },
-- })
