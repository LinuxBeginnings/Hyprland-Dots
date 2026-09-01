#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# User interaction helpers extracted from copy.sh. Each helper echoes state or sets
# globals deliberately to minimize side effects.

# Detect keyboard layout via localectl or setxkbmap.
prompt_detect_layout() {
  if command -v localectl >/dev/null 2>&1; then
    local layout
    layout=$(localectl status --no-pager 2>/dev/null | awk -F': ' '/X11 Layout/ {print $2}' | xargs)
    [ -n "$layout" ] && [ "$layout" != "(unset)" ] && { echo "$layout"; return; }
  fi
  if command -v setxkbmap >/dev/null 2>&1; then
    local layout
    layout=$(setxkbmap -query 2>/dev/null | awk '/layout/ {print $2}')
    [ -n "$layout" ] && { echo "$layout"; return; }
  fi
  echo "us"
}

# Detect keyboard variant via localectl or setxkbmap.
prompt_detect_variant() {
  if command -v localectl >/dev/null 2>&1; then
    local variant
    variant=$(localectl status --no-pager 2>/dev/null | awk -F': ' '/X11 Variant/ {print $2}' | xargs)
    [ -n "$variant" ] && [ "$variant" != "(unset)" ] && { echo "$variant"; return; }
  fi
  if command -v setxkbmap >/dev/null 2>&1; then
    local variant
    variant=$(setxkbmap -query 2>/dev/null | awk '/variant/ {print $2}')
    [ -n "$variant" ] && { echo "$variant"; return; }
  fi
  echo ""
}

# Detect keyboard model via localectl or setxkbmap.
prompt_detect_model() {
  if command -v localectl >/dev/null 2>&1; then
    local model
    model=$(localectl status --no-pager 2>/dev/null | awk -F': ' '/X11 Model/ {print $2}' | xargs)
    [ -n "$model" ] && [ "$model" != "(unset)" ] && { echo "$model"; return; }
  fi
  if command -v setxkbmap >/dev/null 2>&1; then
    local model
    model=$(setxkbmap -query 2>/dev/null | awk '/model/ {print $2}')
    [ -n "$model" ] && { echo "$model"; return; }
  fi
  echo ""
}

# Set keyboard layout in user and system config files (Lua and Hyprlang).
set_keyboard_layout_configs() {
  local new_kb="$1"
  local new_var="${2:-}"
  local new_mod="${3:-}"
  local log="${4:-/dev/null}"
  local base="${DOTFILES_DIR:-.}"
  local cfg_home="${XDG_CONFIG_HOME:-$HOME/.config}"

  export KOOLDOTS_SELECTED_KB_LAYOUT="$new_kb"
  export KOOLDOTS_SELECTED_KB_VARIANT="$new_var"
  export KOOLDOTS_SELECTED_KB_MODEL="$new_mod"

  # 1. Update repo UserConfigs/user_settings.lua & active target user_settings.lua
  local user_lua_files=("$base/config/hypr/UserConfigs/user_settings.lua")
  if [ -f "$cfg_home/hypr/UserConfigs/user_settings.lua" ]; then
    user_lua_files+=("$cfg_home/hypr/UserConfigs/user_settings.lua")
  fi

  for file in "${user_lua_files[@]}"; do
    if [ -f "$file" ]; then
      if grep -q '^[[:space:]]*input[[:space:]]*=' "$file"; then
        if grep -q '^[[:space:]]*kb_layout[[:space:]]*=' "$file"; then
          sed -i "s/^[[:space:]]*kb_layout[[:space:]]*=.*/    kb_layout = \"$new_kb\",/" "$file"
        else
          sed -i "/^[[:space:]]*input[[:space:]]*=/a\\    kb_layout = \"$new_kb\"," "$file"
        fi
        if grep -q '^[[:space:]]*kb_variant[[:space:]]*=' "$file"; then
          sed -i "s/^[[:space:]]*kb_variant[[:space:]]*=.*/    kb_variant = \"$new_var\",/" "$file"
        else
          sed -i "/^[[:space:]]*kb_layout[[:space:]]*=/a\\    kb_variant = \"$new_var\"," "$file"
        fi
        if grep -q '^[[:space:]]*kb_model[[:space:]]*=' "$file"; then
          sed -i "s/^[[:space:]]*kb_model[[:space:]]*=.*/    kb_model = \"$new_mod\",/" "$file"
        else
          sed -i "/^[[:space:]]*kb_variant[[:space:]]*=/a\\    kb_model = \"$new_mod\"," "$file"
        fi
      else
        cat >>"$file" <<EOF

hl.config({
  input = {
    kb_layout = "$new_kb",
    kb_variant = "$new_var",
    kb_model = "$new_mod",
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
EOF
      fi
      echo "${NOTE} Configured keyboard settings in $file" 2>&1 | tee -a "$log"
    fi
  done

  # 2. Update repo lua/settings.lua default & active target lua/settings.lua
  local settings_lua_files=("$base/config/hypr/lua/settings.lua")
  if [ -f "$cfg_home/hypr/lua/settings.lua" ]; then
    settings_lua_files+=("$cfg_home/hypr/lua/settings.lua")
  fi
  for file in "${settings_lua_files[@]}"; do
    if [ -f "$file" ]; then
      sed -i "s/^[[:space:]]*kb_layout[[:space:]]*=.*/    kb_layout = \"$new_kb\",/" "$file"
      sed -i "s/^[[:space:]]*kb_variant[[:space:]]*=.*/    kb_variant = \"$new_var\",/" "$file"
      sed -i "s/^[[:space:]]*kb_model[[:space:]]*=.*/    kb_model = \"$new_mod\",/" "$file"
    fi
  done

  # 3. Update repo UserConfigs/UserSettings.conf & active target UserSettings.conf
  local user_conf_files=("$base/config/hypr/UserConfigs/UserSettings.conf")
  if [ -f "$cfg_home/hypr/UserConfigs/UserSettings.conf" ]; then
    user_conf_files+=("$cfg_home/hypr/UserConfigs/UserSettings.conf")
  fi
  for file in "${user_conf_files[@]}"; do
    if [ -f "$file" ]; then
      if grep -q '^[[:space:]]*input[[:space:]]*{' "$file"; then
        if grep -q '^[[:space:]]*kb_layout[[:space:]]*=' "$file"; then
          sed -i "s/^[[:space:]]*kb_layout[[:space:]]*=.*/  kb_layout = $new_kb/" "$file"
        else
          sed -i "/^[[:space:]]*input[[:space:]]*{/a\\  kb_layout = $new_kb" "$file"
        fi
        if grep -q '^[[:space:]]*kb_variant[[:space:]]*=' "$file"; then
          sed -i "s/^[[:space:]]*kb_variant[[:space:]]*=.*/  kb_variant = $new_var/" "$file"
        else
          sed -i "/^[[:space:]]*kb_layout[[:space:]]*=/a\\  kb_variant = $new_var" "$file"
        fi
        if grep -q '^[[:space:]]*kb_model[[:space:]]*=' "$file"; then
          sed -i "s/^[[:space:]]*kb_model[[:space:]]*=.*/  kb_model = $new_mod/" "$file"
        else
          sed -i "/^[[:space:]]*kb_variant[[:space:]]*=/a\\  kb_model = $new_mod" "$file"
        fi
      else
        cat >>"$file" <<EOF

input {
  kb_layout = $new_kb
  kb_variant = $new_var
  kb_model = $new_mod
}
EOF
      fi
      echo "${NOTE} Configured keyboard settings in $file" 2>&1 | tee -a "$log"
    fi
  done

  # 4. Update repo configs/SystemSettings.conf & active target SystemSettings.conf
  local sys_conf_files=("$base/config/hypr/configs/SystemSettings.conf")
  if [ -f "$cfg_home/hypr/configs/SystemSettings.conf" ]; then
    sys_conf_files+=("$cfg_home/hypr/configs/SystemSettings.conf")
  fi
  for file in "${sys_conf_files[@]}"; do
    if [ -f "$file" ]; then
      awk -v new_layout="$new_kb" '/kb_layout/ {$0 = "  kb_layout = " new_layout} 1' "$file" >temp.conf
      mv temp.conf "$file"
      awk -v new_variant="$new_var" '/kb_variant/ {$0 = "  kb_variant = " new_variant} 1' "$file" >temp.conf
      mv temp.conf "$file"
      awk -v new_model="$new_mod" '/kb_model/ {$0 = "  kb_model = " new_model} 1' "$file" >temp.conf
      mv temp.conf "$file"
    fi
  done
}

# Confirm or set keyboard layout, variant, and model; writes to user_settings.lua and UserSettings.conf.
prompt_keyboard_layout() {
  local layout="${1:-us}"
  local variant="${2:-}"
  local model="${3:-}"
  local log="$4"
  local base="${DOTFILES_DIR:-.}"

  [ "$layout" = "(unset)" ] && layout="us"

  printf "\n${NOTE} Detected keyboard settings:\n"
  printf "  ${INFO} Layout  : ${MAGENTA}%s${RESET}\n" "$layout"
  printf "  ${INFO} Variant : ${MAGENTA}%s${RESET}\n" "${variant:-(none)}"
  printf "  ${INFO} Model   : ${MAGENTA}%s${RESET}\n" "${model:-(none)}"

  while true; do
    echo -n "${CAT} Are these settings correct? [Y/n]: "
    read -r confirm
    confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')
    case "$confirm" in
      y|yes|"")
        set_keyboard_layout_configs "$layout" "$variant" "$model" "$log"
        echo "${NOTE} Keyboard configured: layout='$layout', variant='$variant', model='$model'." 2>&1 | tee -a "$log"
        break
        ;;
      n|no)
        printf "\n%.0s" {1..1}
        print_color $WARNING "\n    █▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█
            CONFIGURE KEYBOARD
    █▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄█

    !!! IMPORTANT WARNING !!!

Setting an invalid Keyboard Layout can cause Hyprland input issues.
If unsure, use ${YELLOW}us${RESET}.
${SKYBLUE}You can change these anytime in ${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/user_settings.lua${RESET}

${MAGENTA} NOTE:${RESET}
• Multiple layouts can be comma-separated: ${YELLOW}us,gb${RESET} or ${YELLOW}us,de${RESET}
"
        echo -n "${CAT} Enter keyboard layout [${layout}]: "
        read -r new_layout
        [ -n "$new_layout" ] && layout="$new_layout"

        echo -n "${CAT} Enter keyboard variant (optional, leave blank for none) [${variant}]: "
        read -r new_variant
        if [ -n "$new_variant" ]; then
          variant="$new_variant"
        fi

        echo -n "${CAT} Enter keyboard model (optional, leave blank for none) [${model}]: "
        read -r new_model
        if [ -n "$new_model" ]; then
          model="$new_model"
        fi

        set_keyboard_layout_configs "$layout" "$variant" "$model" "$log"
        echo "${OK} Keyboard configured: layout='$layout', variant='$variant', model='$model'." 2>&1 | tee -a "$log"
        break
        ;;
      *)
        echo "${ERROR} Please enter 'y' or 'n'."
        ;;
    esac
  done
}

# Prompt for resolution choice; echoes "< 1440p" or "≥ 1440p".
prompt_resolution_choice() {
  local choice
  while true; do
    echo "${INFO:-[INFO]} Select monitor resolution for scaling:"
    echo "  1) < 1440p   (lower DPI; smaller displays)"
    echo "  2) ≥ 1440p   (default; 1440p/2k/4k)"

    if ! read -r -p "${CAT} Enter the number of your choice (1 or 2): " choice </dev/tty; then
      echo "${ERROR} Unable to read input (tty unavailable)."
      continue
    fi
    echo "${INFO:-[INFO]} You entered: '$choice'"
    case "$choice" in
      1) echo "< 1440p"; return ;;
      2) echo "≥ 1440p"; return ;;
      *) echo "${ERROR} Invalid choice. Please enter 1 for < 1440p or 2 for ≥ 1440p." ;;
    esac
  done
}

# Prompt for 12H clock; sets waybar/hyprlock/SDDM changes when accepted.
prompt_clock_12h() {
  local log="$1"
  local base="${DOTFILES_DIR:-.}"
  while true; do
    echo -e "${NOTE} ${SKY_BLUE} By default, KooL's Dots are configured in 24H clock format."
    echo -n "$CAT Do you want to change to 12H (AM/PM) clock format? (y/n): "
    read answer
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
    if [[ "$answer" == "y" ]]; then
      # waybar clocks
      sed -i 's#^\(\s*\)//\("format": " {:%I:%M %p}",\) #\1\2 #g' "$base/config/waybar/Modules" 2>&1 | tee -a "$log"
      sed -i 's#^\(\s*\)\("format": " {:%H:%M:%S}",\) #\1//\2#g' "$base/config/waybar/Modules" 2>&1 | tee -a "$log"
      sed -i 's#^\(\s*\)\("format": "  {:%H:%M}",\) #\1//\2#g' "$base/config/waybar/Modules" 2>&1 | tee -a "$log"
      sed -i 's#^\(\s*\)//\("format": "{:%I:%M %p - %d/%b}",\) #\1\2#g' "$base/config/waybar/Modules" 2>&1 | tee -a "$log"
      sed -i 's#^\(\s*\)\("format": "{:%H:%M - %d/%b}",\) #\1//\2#g' "$base/config/waybar/Modules" 2>&1 | tee -a "$log"
      sed -i 's#^\(\s*\)//\("format": "{:%B | %a %d, %Y | %I:%M %p}",\) #\1\2#g' "$base/config/waybar/Modules" 2>&1 | tee -a "$log"
      sed -i 's#^\(\s*\)\("format": "{:%B | %a %d, %Y | %H:%M}",\) #\1//\2#g' "$base/config/waybar/Modules" 2>&1 | tee -a "$log"
      sed -i 's#^\(\s*\)//\("format": "{:%A, %I:%M %P}",\) #\1\2#g' "$base/config/waybar/Modules" 2>&1 | tee -a "$log"
      sed -i 's#^\(\s*\)\("format": "{:%a %d | %H:%M}",\) #\1//\2#g' "$base/config/waybar/Modules" 2>&1 | tee -a "$log"

      # hyprlock
      local HYPRLOCK_FILE="$base/config/hypr/hyprlock.conf"
      if [ ! -f "$HYPRLOCK_FILE" ] && [ -f "$base/config/hypr/hyprlock-1080p.conf" ]; then
        HYPRLOCK_FILE="$base/config/hypr/hyprlock-1080p.conf"
      fi
      if [ -f "$HYPRLOCK_FILE" ]; then
        sed -i 's/^\s*text = cmd\[update:1000\] echo \"\$(date +\"%H\")\"/# &/' "$HYPRLOCK_FILE" 2>&1 | tee -a "$log"
        sed -i 's/^\(\s*\)# *text = cmd\[update:1000\] echo \"\$(date +\"%I\")\" #AM\/PM/\1    text = cmd\[update:1000\] echo \"\$(date +\"%I\")\" #AM\/PM/' "$HYPRLOCK_FILE" 2>&1 | tee -a "$log"
        sed -i 's/^\s*text = cmd\[update:1000\] echo \"\$(date +\"%S\")\"/# &/' "$HYPRLOCK_FILE" 2>&1 | tee -a "$log"
        sed -i 's/^\(\s*\)# *text = cmd\[update:1000\] echo \"\$(date +\"%S %p\")\" #AM\/PM/\1    text = cmd\[update:1000\] echo \"\$(date +\"%S %p\")\" #AM\/PM/' "$HYPRLOCK_FILE" 2>&1 | tee -a "$log"
      else
        echo "${WARN} hyprlock template not found; skipping 12H lock format edits" 2>&1 | tee -a "$log"
      fi

      if [ "${EXPRESS_MODE:-0}" -eq 0 ]; then
        apply_sddm_12h_format "/usr/share/sddm/themes/simple-sddm" "$log"
        apply_sddm_12h_format "/usr/share/sddm/themes/simple_sddm_2" "$log"
        apply_sddm_12h_format_sequoia "/usr/share/sddm/themes/sequoia_2" "$log"
      else
        echo "${NOTE:-[NOTE]} Express mode: skipping SDDM 12H edits to avoid sudo prompts." 2>&1 | tee -a "$log"
      fi
      echo "${OK} 12H format set on waybar clocks succesfully." 2>&1 | tee -a "$log"
      return
    elif [[ "$answer" == "n" ]]; then
      echo "${NOTE} You chose not to change to 12H format." 2>&1 | tee -a "$log"
      return
    else
      echo "${ERROR} Invalid choice. Please enter y for yes or n for no."
    fi
  done
}

apply_sddm_12h_format() {
  local sddm_directory="$1"
  local log="$2"
  if [ -d "$sddm_directory" ]; then
    echo "Editing ${SKY_BLUE}$sddm_directory${RESET} to 12H format" 2>&1 | tee -a "$log"
    if ! sudo -n sed -i 's|^## HourFormat="hh:mm AP"|HourFormat="hh:mm AP"|' "$sddm_directory/theme.conf" 2>&1 | tee -a "$log"; then
      echo "${WARN:-[WARN]} Skipping SDDM 12H edit (sudo password required)." 2>&1 | tee -a "$log"
      return
    fi
    sudo -n sed -i 's|^HourFormat="HH:mm"|## HourFormat="HH:mm"|' "$sddm_directory/theme.conf" 2>&1 | tee -a "$log" || true
  fi
}

apply_sddm_12h_format_sequoia() {
  local sddm_directory="$1"
  local log="$2"
  if [ -d "$sddm_directory" ]; then
    echo "${YELLOW}sddm sequoia_2${RESET} theme exists. Editing to 12H format" 2>&1 | tee -a "$log"
    if ! sudo -n sed -i 's|^clockFormat="HH:mm"|## clockFormat="HH:mm"|' "$sddm_directory/theme.conf" 2>&1 | tee -a "$log"; then
      echo "${WARN:-[WARN]} Skipping sequoia SDDM 12H edit (sudo password required)." 2>&1 | tee -a "$log"
      return
    fi
    if ! grep -q 'clockFormat="hh:mm AP"' "$sddm_directory/theme.conf"; then
      sudo -n sed -i '/^clockFormat=/a clockFormat="hh:mm AP"' "$sddm_directory/theme.conf" 2>&1 | tee -a "$log" || true
    fi
    echo "${OK} 12H format set to SDDM successfully." 2>&1 | tee -a "$log"
  fi
}


# Confirm Hyprlang -> Lua migration during upgrade/express workflows.
# Sets MIGRATE_HYPR_TO_LUA=1 (default yes) or 0 when the user declines.
prompt_lua_migration() {
  local log="${1:-/dev/null}"
  local hypr_dir
  hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"

  MIGRATE_HYPR_TO_LUA=1

  # Already on Lua entrypoint: still refresh/migrate overlays after upgrade copy.
  if [ -f "$hypr_dir/hyprland.lua" ]; then
    echo "${NOTE:-[NOTE]} Existing Hyprland Lua config detected; migration will refresh Lua overlays after upgrade." 2>&1 | tee -a "$log"
    export MIGRATE_HYPR_TO_LUA
    return 0
  fi

  printf "\n%.0s" {1..1}
  echo "${WARNING:-[WARN]} Hyprland will be LUA-only in the next release.${RESET:-}"
  echo "${NOTE:-[NOTE]} This upgrade will migrate your Hyprlang (.conf) configuration to LUA."
  echo "${NOTE:-[NOTE]} A backup is created first; hyprland.conf remains as fallback."
  while true; do
    if ! read -r -p "${CAT:-[ACTION]} Configuration will be migrated to LUA. Continue? (Y/n): " lua_migrate_choice </dev/tty; then
      echo "${WARN:-[WARN]} Unable to read input; defaulting to migrate to LUA." 2>&1 | tee -a "$log"
      break
    fi
    case "$lua_migrate_choice" in
    [Yy] | [Yy][Ee][Ss] | "")
      MIGRATE_HYPR_TO_LUA=1
      echo "${INFO:-[INFO]} LUA migration approved for this upgrade." 2>&1 | tee -a "$log"
      break
      ;;
    [Nn] | [Nn][Oo])
      MIGRATE_HYPR_TO_LUA=0
      echo "${WARN:-[WARN]} Skipping LUA migration; remaining on Hyprlang (.conf) for now." 2>&1 | tee -a "$log"
      echo "${NOTE:-[NOTE]} You can migrate later with: scripts/migrate-hypr-to-lua.sh" 2>&1 | tee -a "$log"
      break
      ;;
    *)
      echo "${WARN:-[WARN]} Please answer Y or n."
      ;;
    esac
  done

  export MIGRATE_HYPR_TO_LUA
}

# Express upgrade confirmation; may set EXPRESS_MODE=1.
prompt_express_upgrade() {
  local express_supported="$1"
  local log="$2"
  if [ "$EXPRESS_MODE" -eq 1 ] && [ "$express_supported" -eq 0 ]; then
    echo "${NOTE} Express mode requires installed dotfiles v${MIN_EXPRESS_VERSION} or newer. Continuing with standard upgrade prompts." 2>&1 | tee -a "$log"
    EXPRESS_MODE=0
    return
  fi
  if [ "$UPGRADE_MODE" -eq 1 ] && [ "$EXPRESS_MODE" -eq 0 ]; then
    if [ "$express_supported" -eq 0 ]; then
      echo "${NOTE} Express mode requires installed dotfiles v${MIN_EXPRESS_VERSION} or newer. Continuing with standard upgrade prompts." 2>&1 | tee -a "$log"
    else
      while true; do
        echo "${NOTE} Express mode skips config restore prompts, SDDM/background questions, and trims old backups."
        if ! read -r -p "${CAT} Do you want to continue with EXPRESS upgrade mode? (y/N): " express_choice </dev/tty; then
          echo "${ERROR} Unable to read input for express choice; defaulting to standard prompts." 2>&1 | tee -a "$log"
          break
        fi
        case "$express_choice" in
          [Yy])
            EXPRESS_MODE=1
            echo "${INFO} Express mode enabled for this upgrade." 2>&1 | tee -a "$log"
            break
            ;;
          [Nn] | "")
            echo "${NOTE} Continuing with standard upgrade prompts." 2>&1 | tee -a "$log"
            break
            ;;
          *)
            echo "${WARN} Please answer y or n."
            ;;
        esac
      done
    fi
  fi
}
