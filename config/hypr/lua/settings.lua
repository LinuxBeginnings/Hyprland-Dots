-- Converted from:
-- - config/hypr/configs/SystemSettings.conf
-- - config/hypr/UserConfigs/UserSettings.conf (currently empty)

local scriptsDir = "$HOME/.config/hypr/scripts"

hl.config({
  dwindle = {
    preserve_split = true,
    smart_resizing = true,
    use_active_for_splits = true,
    smart_split = false,
    default_split_ratio = 1.0,
    split_bias = 0,
    precise_mouse_move = false,
    special_scale_factor = 0.8,
  },
})

hl.config({
  master = {
    new_status = "slave",
    new_on_top = false,
    new_on_active = "none",
    orientation = "left",
    mfact = 0.55,
    slave_count_for_center_master = 2,
    center_master_fallback = "left",
    smart_resizing = true,
    drop_at_cursor = true,
    always_keep_position = false,
  },
})

hl.config({
  scrolling = {
    column_width = 0.80,
    fullscreen_on_one_column = true,
    direction = "right",
    follow_focus = true,
  },
})

hl.config({
  general = {
    resize_on_border = true,
    layout = "dwindle",
  },
})

hl.config({
  input = {
    kb_layout = "us",
    kb_variant = "",
    kb_model = "",
    kb_options = "",
    kb_rules = "",
    repeat_rate = 50,
    repeat_delay = 300,
    sensitivity = 0,
    numlock_by_default = true,
    left_handed = false,
    follow_mouse = 1,
    float_switch_override_focus = false,
    touchpad = {
      disable_while_typing = true,
      natural_scroll = true,
      clickfinger_behavior = false,
      middle_button_emulation = false,
      tap_to_click = true,
      drag_lock = false,
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

hl.config({
  gestures = {
    workspace_swipe_distance = 300,
    workspace_swipe_touch = false,
    workspace_swipe_invert = true,
    workspace_swipe_min_speed_to_force = 30,
    workspace_swipe_cancel_ratio = 0.5,
    workspace_swipe_create_new = true,
    workspace_swipe_direction_lock = true,
    workspace_swipe_forever = false,
    workspace_swipe_use_r = false,
    close_max_timeout = 100,
  },
})

hl.gesture({
  fingers = 3,
  direction = "horizontal",
  action = "workspace",
})

-- Complex dispatcher gestures from SystemSettings.conf are pending explicit Lua API parity:
-- gesture = 3, up, dispatcher, exec, hyprctl keyword cursor:zoom_factor ...
-- gesture = 3, down, dispatcher, exec, hyprctl keyword cursor:zoom_factor ...
-- gesture = 4, up, dispatcher, exec, $scriptsDir/OverviewToggle.sh
-- gesture = 4, down, float

hl.config({
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    vrr = 2,
    mouse_move_enables_dpms = true,
    enable_swallow = false,
    swallow_regex = "^(kitty)$",
    focus_on_activate = false,
    initial_workspace_tracking = 0,
    middle_click_paste = false,
    enable_anr_dialog = true,
    anr_missed_pings = 15,
    allow_session_lock_restore = true,
    on_focus_under_fullscreen = 1,
  },
})

hl.config({
  binds = {
    workspace_back_and_forth = true,
    allow_workspace_cycles = true,
    pass_mouse_when_bound = false,
  },
})

hl.config({
  xwayland = {
    enabled = true,
    force_zero_scaling = true,
  },
})

hl.config({
  render = {
    direct_scanout = 0,
  },
})

hl.config({
  cursor = {
    sync_gsettings_theme = true,
    no_hardware_cursors = 2,
    enable_hyprcursor = true,
    warp_on_change_workspace = 2,
    no_warps = true,
    no_break_fs_vrr = false,
    min_refresh_rate = 24,
    hotspot_padding = 1,
    inactive_timeout = 0,
    default_monitor = "",
    zoom_factor = 1.0,
    zoom_rigid = false,
    zoom_detached_camera = true,
    hide_on_key_press = true,
    hide_on_touch = false,
    hide_on_tablet = false,
    use_cpu_buffer = false,
  },
})
