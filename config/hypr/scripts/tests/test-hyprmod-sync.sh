#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Test suite for HyprModSync.sh: synchronizing HyprMod's managed
#   file (hyprland-gui.lua) with KoolDots split UserConfigs files.
#
# Covers:
#   - Export from managed file to split files (to-split)
#   - Import from split files into managed file (to-managed)
#   - Preservation of existing code outside managed block
#   - Clearing managed blocks when managed file is empty
#   - Auto-sync direction based on mtime
#   - Custom config path via --config
#   - Status reporting

set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

SCRIPT="$HERE/../HyprModSync.sh"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

CFG="$WORK/hypr"
USERCFG="$CFG/UserConfigs"
TOML="$USERCFG/hyprmod.toml"
MANAGED="$CFG/hyprland-gui.lua"
ENTRY="$CFG/hyprland.lua"

mkdir -p "$USERCFG"
touch "$ENTRY"

cat > "$TOML" << EOF
[paths]
base_dir = "$CFG"
entrypoint = "hyprland.lua"

[targets]
monitors   = "UserConfigs/monitors.lua"
binds      = "UserConfigs/user_keybinds.lua"
rules      = "UserConfigs/user_window_rules.lua"
animations = "UserConfigs/user_animations.lua"
appearance = "UserConfigs/user_decorations.lua"
settings   = "UserConfigs/user_settings.lua"
EOF

# --- status command ----------------------------------------------------------
it "status command reports base dir and targets"
out="$(bash "$SCRIPT" -c "$TOML" status)"
assert_contains "$out" "Base Directory:" "status shows base directory"
assert_contains "$out" "monitors" "status lists monitors target"
assert_contains "$out" "binds" "status lists binds target"

# --- to-split with sample managed file ----------------------------------------
it "to-split extracts binds, monitors, and appearance into designated targets"
cat > "$MANAGED" << 'EOF'
hl.config({
    general = {
        border_size = 3,
        gaps_in = 8,
    },
    decoration = {
        rounding = 15,
    },
    input = {
        sensitivity = 0.8,
    },
})

hl.monitor({
    output = "DP-1",
    disabled = false,
    mode = "2560x1440@144",
    position = "0x0",
    scale = 1,
})

hl.bind("SUPER + Return", hl.dsp.exec_cmd("ghostty"))
hl.bind("SUPER + Q", hl.dsp.window.close())

hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 5,
    bezier = "easeOutQuint",
})

hl.window_rule({
    match = {
        class = "pavucontrol",
    },
    float = true,
})
EOF

# Pre-populate user_keybinds.lua with custom code
cat > "$USERCFG/user_keybinds.lua" << 'EOF'
-- User manual keybinds
local bind = function(...) end
bind("SUPER", "Z", "custom_action")
EOF

bash "$SCRIPT" -c "$TOML" to-split

# Check binds
binds_content="$(cat "$USERCFG/user_keybinds.lua")"
assert_contains "$binds_content" "local bind = function(...) end" "pre-existing user code is preserved"
assert_contains "$binds_content" "-- >>> HYPRMOD MANAGED BLOCK >>>" "managed block start marker exists"
assert_contains "$binds_content" 'hl.bind("SUPER + Return", hl.dsp.exec_cmd("ghostty"))' "ghostty bind was synced"
assert_contains "$binds_content" 'hl.bind("SUPER + Q", hl.dsp.window.close())' "close bind was synced"
assert_contains "$binds_content" "-- <<< END HYPRMOD MANAGED BLOCK <<<" "managed block end marker exists"

# Check monitors
monitors_content="$(cat "$USERCFG/monitors.lua")"
assert_contains "$monitors_content" 'output = "DP-1"' "DP-1 monitor synced"
assert_contains "$monitors_content" 'mode = "2560x1440@144"' "monitor mode synced"

# Check appearance
decorations_content="$(cat "$USERCFG/user_decorations.lua")"
assert_contains "$decorations_content" 'border_size = 3' "general border_size synced to appearance"
assert_contains "$decorations_content" 'rounding = 15' "decoration rounding synced to appearance"

# Check settings
settings_content="$(cat "$USERCFG/user_settings.lua")"
assert_contains "$settings_content" 'sensitivity = 0.8' "input sensitivity synced to settings"

# Check rules
rules_content="$(cat "$USERCFG/user_window_rules.lua")"
assert_contains "$rules_content" 'class = "pavucontrol"' "window rule for pavucontrol synced"

# --- update managed block on second to-split ----------------------------------
it "updating managed file cleanly replaces managed block without duplicating"
cat > "$MANAGED" << 'EOF'
hl.bind("SUPER + Return", hl.dsp.exec_cmd("alacritty"))
EOF

bash "$SCRIPT" -c "$TOML" to-split
binds_updated="$(cat "$USERCFG/user_keybinds.lua")"
assert_contains "$binds_updated" "local bind = function(...) end" "user code still preserved"
assert_contains "$binds_updated" 'hl.bind("SUPER + Return", hl.dsp.exec_cmd("alacritty"))' "updated bind is present"
assert_not_contains "$binds_updated" 'ghostty' "old bind was replaced"

# Count occurrences of start marker
marker_count="$(grep -c -- "-- >>> HYPRMOD MANAGED BLOCK >>>" "$USERCFG/user_keybinds.lua" || true)"
assert_eq "managed block appears exactly once" "1" "$marker_count"

# --- empty managed file clears managed block ----------------------------------
it "empty managed file removes managed block from split files"
: > "$MANAGED"
bash "$SCRIPT" -c "$TOML" to-split
binds_cleared="$(cat "$USERCFG/user_keybinds.lua")"
assert_contains "$binds_cleared" "local bind = function(...) end" "user code remains"
assert_not_contains "$binds_cleared" "HYPRMOD MANAGED BLOCK" "managed block is removed"

# --- to-managed compiles split files into hyprland-gui.lua --------------------
it "to-managed compiles blocks from split files into hyprland-gui.lua"
cat > "$USERCFG/monitors.lua" << 'EOF'
-- >>> HYPRMOD MANAGED BLOCK >>>
hl.monitor({
    output = "HDMI-A-1",
    disabled = false,
    mode = "1920x1080@60",
    position = "0x0",
    scale = 1,
})
-- <<< END HYPRMOD MANAGED BLOCK <<<
EOF

cat > "$USERCFG/user_keybinds.lua" << 'EOF'
-- custom user code
-- >>> HYPRMOD MANAGED BLOCK >>>
hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))
-- <<< END HYPRMOD MANAGED BLOCK <<<
EOF

bash "$SCRIPT" -c "$TOML" to-managed
managed_compiled="$(cat "$MANAGED")"
assert_contains "$managed_compiled" 'output = "HDMI-A-1"' "compiled monitor block into managed file"
assert_contains "$managed_compiled" 'hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))' "compiled bind block into managed file"

summary "test-hyprmod-sync"
