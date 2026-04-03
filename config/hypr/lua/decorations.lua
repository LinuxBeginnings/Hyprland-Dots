-- Converted from config/hypr/UserConfigs/UserDecorations.conf.
-- NOTE: wallust-hyprland.conf is hyprlang-sourced in the original config.
-- Lua parity for importing that file is still evolving; using static color fallbacks here.

hl.config({
    general = {
        border_size = 2,
        gaps_in = 2,
        gaps_out = 4,
        col = {
            active_border = "rgba(8db4ffff)",
            inactive_border = "rgba(5f6578ff)",
        },
    },
})

hl.config({
    decoration = {
        rounding = 10,
        active_opacity = 1.0,
        inactive_opacity = 0.9,
        fullscreen_opacity = 1.0,
        dim_inactive = true,
        dim_strength = 0.1,
        dim_special = 0.8,
        shadow = {
            enabled = true,
            range = 3,
            render_power = 1,
            color = "rgba(8db4ffff)",
            color_inactive = "rgba(5f6578ff)",
        },
        blur = {
            enabled = true,
            size = 6,
            passes = 3,
            new_optimizations = true,
            xray = true,
            ignore_opacity = true,
            special = true,
            popups = true,
        },
    },
})

hl.config({
    group = {
        col = {
            border_active = "rgba(ffffffff)",
        },
        groupbar = {
            col = {
                active = "rgba(0f111aff)",
            },
        },
    },
})
