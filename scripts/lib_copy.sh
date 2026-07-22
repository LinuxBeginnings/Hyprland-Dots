#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Copy helpers split into phases to keep copy.sh lean.

copy_phase1() {
  local log="$1"
  local base="${DOTFILES_DIR:-.}"
  local dirs="fastfetch kitty rofi swaync"
  for DIR2 in $dirs; do
    local DIRPATH="${XDG_CONFIG_HOME:-$HOME/.config}/$DIR2"
    if [ -d "$DIRPATH" ]; then
      while true; do
        printf "\n${INFO:-[INFO]} Found ${YELLOW:-}$DIR2${RESET:-} config found in ${XDG_CONFIG_HOME:-$HOME/.config}/\n"
        echo -n "${CAT:-[ACTION]} Do you want to replace ${YELLOW:-}$DIR2${RESET:-} config? (y/n): "
        read DIR1_CHOICE
        case "$DIR1_CHOICE" in
        [Yy]*)
          BACKUP_DIR=$(get_backup_dirname)
          mv "$DIRPATH" "$DIRPATH-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
          echo -e "${NOTE:-[NOTE]} - Backed up $DIR2 to $DIRPATH-backup-$BACKUP_DIR." 2>&1 | tee -a "$log"
          cp -r "$base/config/$DIR2" "${XDG_CONFIG_HOME:-$HOME/.config}/$DIR2" 2>&1 | tee -a "$log"
          echo -e "${OK:-[OK]} - Replaced $DIR2 with new configuration." 2>&1 | tee -a "$log"
          if [ "$DIR2" = "rofi" ]; then
            if [ -d "$DIRPATH-backup-$BACKUP_DIR/themes" ]; then
              for file in "$DIRPATH-backup-$BACKUP_DIR/themes"/*; do
                [ -e "$file" ] || continue
                cp -n "$file" "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/themes/" >>"$log" 2>&1 || true
              done || true
            fi
            if [ -f "$DIRPATH-backup-$BACKUP_DIR/config.rasi" ]; then
              cp -f "$DIRPATH-backup-$BACKUP_DIR/config.rasi" "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/config.rasi" >>"$log" 2>&1 || true
            fi
            if [ -f "$DIRPATH-backup-$BACKUP_DIR/0-shared-fonts.rasi" ]; then
              cp "$DIRPATH-backup-$BACKUP_DIR/0-shared-fonts.rasi" "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/0-shared-fonts.rasi" >>"$log" 2>&1
            fi
          fi
          break
          ;;
        [Nn]*)
          echo -e "${NOTE:-[NOTE]} - Skipping ${YELLOW:-}$DIR2${RESET:-}" 2>&1 | tee -a "$log"
          break
          ;;
        *) echo -e "${WARN:-[WARN]} - Invalid choice. Please enter Y or N." ;;
        esac
      done
    else
      cp -r "$base/config/$DIR2" "${XDG_CONFIG_HOME:-$HOME/.config}/$DIR2" 2>&1 | tee -a "$log"
      echo -e "${OK:-[OK]} - Copy completed for ${YELLOW:-}$DIR2${RESET:-}" 2>&1 | tee -a "$log"
    fi
  done
}

copy_waybar() {
  local log="$1"
  local base="${DOTFILES_DIR:-.}"
  local DIRW="waybar"
  local DIRPATHw="${XDG_CONFIG_HOME:-$HOME/.config}/$DIRW"
  if [ -d "$DIRPATHw" ]; then
    while true; do
      echo -n "${CAT:-[ACTION]} Do you want to replace ${YELLOW:-}$DIRW${RESET:-} config? (y/n): "
      read DIR1_CHOICE
      case "$DIR1_CHOICE" in
      [Yy]*)
        BACKUP_DIR=$(get_backup_dirname)
        cp -r "$DIRPATHw" "$DIRPATHw-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
        echo -e "${NOTE:-[NOTE]} - Backed up $DIRW to $DIRPATHw-backup-$BACKUP_DIR." 2>&1 | tee -a "$log"
        rm -rf "$DIRPATHw" && cp -r "$base/config/$DIRW" "$DIRPATHw" 2>&1 | tee -a "$log"
        for file in "config" "style.css"; do
          symlink="$DIRPATHw-backup-$BACKUP_DIR/$file"
          target_file="$DIRPATHw/$file"
          if [ -L "$symlink" ]; then
            symlink_target=$(readlink "$symlink")
            if [ -f "$symlink_target" ]; then
              rm -f "$target_file" && cp -f "$symlink_target" "$target_file"
            fi
          fi
        done
        for dir in "$DIRPATHw-backup-$BACKUP_DIR/configs"/*; do
          [ -e "$dir" ] || continue
          if [ -d "$dir" ]; then
            target_dir="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/configs/$(basename "$dir")"
            [ -d "$target_dir" ] || cp -r "$dir" "${XDG_CONFIG_HOME:-$HOME/.config}/waybar/configs/"
          fi
        done
        for file in "$DIRPATHw-backup-$BACKUP_DIR/configs"/*; do
          [ -e "$file" ] || continue
          target_file="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/configs/$(basename "$file")"
          [ -e "$target_file" ] || cp "$file" "${XDG_CONFIG_HOME:-$HOME/.config}/waybar/configs/"
        done || true
        for file in "$DIRPATHw-backup-$BACKUP_DIR/style"/*; do
          [ -e "$file" ] || continue
          if [ -d "$file" ]; then
            target_dir="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/style/$(basename "$file")"
            [ -d "$target_dir" ] || cp -r "$file" "${XDG_CONFIG_HOME:-$HOME/.config}/waybar/style/"
          else
            target_file="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/style/$(basename "$file")"
            [ -e "$target_file" ] || cp "$file" "${XDG_CONFIG_HOME:-$HOME/.config}/waybar/style/"
          fi
        done || true
        BACKUP_FILEw="$DIRPATHw-backup-$BACKUP_DIR/UserModules"
        [ -f "$BACKUP_FILEw" ] && cp -f "$BACKUP_FILEw" "$DIRPATHw/UserModules"
        break
        ;;
      [Nn]*)
        echo -e "${NOTE:-[NOTE]} - Skipping ${YELLOW:-}$DIRW${RESET:-} config replacement." 2>&1 | tee -a "$log"
        break
        ;;
      *) echo -e "${WARN:-[WARN]} - Invalid choice. Please enter Y or N." ;;
      esac
    done
  else
    cp -r "$base/config/$DIRW" "$DIRPATHw" 2>&1 | tee -a "$log"
    echo -e "${OK:-[OK]} - Copy completed for ${YELLOW:-}$DIRW${RESET:-}" 2>&1 | tee -a "$log"
  fi
}

copy_phase2() {
  local log="$1"
  local base="${DOTFILES_DIR:-.}"
  local DIR="btop cava hypr Kvantum qt5ct qt6ct starship swappy wallust wlogout yazi"
  for DIR_NAME in $DIR; do
    local DIRPATH="${XDG_CONFIG_HOME:-$HOME/.config}/$DIR_NAME"
    if [ -d "$DIRPATH" ]; then
      echo -e "\n${NOTE:-[NOTE]} - Config for ${YELLOW:-}$DIR_NAME${RESET:-} found, attempting to back up."
      BACKUP_DIR=$(get_backup_dirname)
      mv "$DIRPATH" "$DIRPATH-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
    fi
    if [ -d "$base/config/$DIR_NAME" ]; then
      cp -r "$base/config/$DIR_NAME/" "${XDG_CONFIG_HOME:-$HOME/.config}/$DIR_NAME" 2>&1 | tee -a "$log"
      echo "${OK:-[OK]} - Copy of config for ${YELLOW:-}$DIR_NAME${RESET:-} completed!" 2>&1 | tee -a "$log"
    else
      echo "${ERROR:-[ERROR]} - Directory config/$DIR_NAME does not exist to copy." 2>&1 | tee -a "$log"
    fi
  done
  install_terminal_configs "$log"
}

ensure_lua_keybinds() {
  local log="$1"
  local base="${DOTFILES_DIR:-.}"
  local src_root="$base/config/hypr"
  local dst_root="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  local copied=0
  local rel_dir src_dir src_file rel_path dst_file

  for rel_dir in configs UserConfigs lua; do
    src_dir="$src_root/$rel_dir"
    [ -d "$src_dir" ] || continue

    while IFS= read -r -d '' src_file; do
      rel_path="${src_file#$src_root/}"
      dst_file="$dst_root/$rel_path"

      if [ ! -f "$dst_file" ]; then
        mkdir -p "$(dirname "$dst_file")"
        if cp -f "$src_file" "$dst_file" 2>&1 | tee -a "$log"; then
          copied=1
          echo "${NOTE:-[NOTE]} - Added missing Lua file: ${YELLOW:-}$rel_path${RESET:-}" 2>&1 | tee -a "$log"
        else
          echo "${ERROR:-[ERROR]} - Failed to add missing Lua file: ${YELLOW:-}$rel_path${RESET:-}" 2>&1 | tee -a "$log"
        fi
      fi
    done < <(find "$src_dir" -maxdepth 1 -type f -name '*.lua' -print0)
  done

  if [ "$copied" -eq 1 ]; then
    echo "${OK:-[OK]} - Lua fallback copy completed." 2>&1 | tee -a "$log"
  else
    echo "${INFO:-[INFO]} - Lua fallback check: no missing Lua files detected." 2>&1 | tee -a "$log"
  fi
}
seed_upgrade_userconfigs() {
  local log="$1"
  local cfg_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local userconfigs_dir="$cfg_home/hypr/UserConfigs"
  local repo_userconfigs="${DOTFILES_DIR:-.}/config/hypr/UserConfigs"
  local runtime_kitty="$cfg_home/kitty/kitty.conf"
  local runtime_ghostty="$cfg_home/ghostty/config"
  local runtime_hyprview="$userconfigs_dir/hyprview-layout.conf"

  mkdir -p "$userconfigs_dir"

  if [ ! -f "$userconfigs_dir/kitty.conf" ] && [ -f "$runtime_kitty" ]; then
    cp -f "$runtime_kitty" "$userconfigs_dir/kitty.conf" 2>&1 | tee -a "$log"
    echo "${NOTE:-[NOTE]} - Seeded UserConfigs/kitty.conf from current kitty config." 2>&1 | tee -a "$log"
  fi

  if [ ! -f "$userconfigs_dir/ghostty.conf" ] && [ -f "$runtime_ghostty" ]; then
    cp -f "$runtime_ghostty" "$userconfigs_dir/ghostty.conf" 2>&1 | tee -a "$log"
    echo "${NOTE:-[NOTE]} - Seeded UserConfigs/ghostty.conf from current ghostty/config." 2>&1 | tee -a "$log"
  fi

  if [ ! -f "$runtime_hyprview" ] && [ -f "$repo_userconfigs/hyprview-layout.conf" ]; then
    cp -f "$repo_userconfigs/hyprview-layout.conf" "$runtime_hyprview" 2>&1 | tee -a "$log"
    echo "${NOTE:-[NOTE]} - Seeded UserConfigs/hyprview-layout.conf from repo default." 2>&1 | tee -a "$log"
  fi
}

capture_upgrade_runtime_selection_state() {
  local cfg_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local waybar_config_link="$cfg_home/waybar/config"
  local waybar_style_link="$cfg_home/waybar/style.css"
  local rofi_config="$cfg_home/rofi/config.rasi"

  KOOLDOTS_PREV_WAYBAR_CONFIG_TARGET=""
  KOOLDOTS_PREV_WAYBAR_STYLE_TARGET=""
  KOOLDOTS_PREV_ROFI_THEME_PATH=""

  if [ "${RUN_MODE:-}" = "install" ]; then
    export KOOLDOTS_PREV_WAYBAR_CONFIG_TARGET
    export KOOLDOTS_PREV_WAYBAR_STYLE_TARGET
    export KOOLDOTS_PREV_ROFI_THEME_PATH
    return
  fi

  if [ -e "$waybar_config_link" ]; then
    if [ -L "$waybar_config_link" ]; then
      KOOLDOTS_PREV_WAYBAR_CONFIG_TARGET="$(readlink -f "$waybar_config_link" 2>/dev/null || true)"
    else
      KOOLDOTS_PREV_WAYBAR_CONFIG_TARGET="$waybar_config_link"
    fi
  fi

  if [ -e "$waybar_style_link" ]; then
    if [ -L "$waybar_style_link" ]; then
      KOOLDOTS_PREV_WAYBAR_STYLE_TARGET="$(readlink -f "$waybar_style_link" 2>/dev/null || true)"
    else
      KOOLDOTS_PREV_WAYBAR_STYLE_TARGET="$waybar_style_link"
    fi
  fi

  if [ -f "$rofi_config" ]; then
    KOOLDOTS_PREV_ROFI_THEME_PATH="$(
      awk -F'"' '/^[[:space:]]*@theme[[:space:]]*"/ {print $2}' "$rofi_config" | tail -n1
    )"
  fi

  export KOOLDOTS_PREV_WAYBAR_CONFIG_TARGET
  export KOOLDOTS_PREV_WAYBAR_STYLE_TARGET
  export KOOLDOTS_PREV_ROFI_THEME_PATH
}

restore_upgrade_runtime_selection_state() {
  local log="$1"
  local cfg_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local waybar_config_link="$cfg_home/waybar/config"
  local waybar_style_link="$cfg_home/waybar/style.css"
  local rofi_config="$cfg_home/rofi/config.rasi"
  local waybar_configs_dir="$cfg_home/waybar/configs"
  local waybar_style_dir="$cfg_home/waybar/style"
  local target
  local target_base

  if [ "${RUN_MODE:-}" = "install" ]; then
    return
  fi

  target="${KOOLDOTS_PREV_WAYBAR_CONFIG_TARGET:-}"
  if [ -n "$target" ]; then
    if [ -e "$target" ]; then
      ln -sf "$target" "$waybar_config_link" 2>&1 | tee -a "$log"
    else
      target_base="$(basename "$target")"
      if [ -e "$waybar_configs_dir/$target_base" ]; then
        ln -sf "$waybar_configs_dir/$target_base" "$waybar_config_link" 2>&1 | tee -a "$log"
      fi
    fi
  fi

  target="${KOOLDOTS_PREV_WAYBAR_STYLE_TARGET:-}"
  if [ -n "$target" ]; then
    if [ -e "$target" ]; then
      ln -sf "$target" "$waybar_style_link" 2>&1 | tee -a "$log"
    else
      target_base="$(basename "$target")"
      if [ -e "$waybar_style_dir/$target_base" ]; then
        ln -sf "$waybar_style_dir/$target_base" "$waybar_style_link" 2>&1 | tee -a "$log"
      fi
    fi
  fi

  if [ -n "${KOOLDOTS_PREV_ROFI_THEME_PATH:-}" ] && [ -f "$rofi_config" ]; then
    sed -i -E 's/^([[:space:]]*@theme)/\/\/\1/' "$rofi_config" 2>/dev/null || true
    printf '\n@theme "%s"\n' "$KOOLDOTS_PREV_ROFI_THEME_PATH" >>"$rofi_config"
    echo "${NOTE:-[NOTE]} - Restored previous Rofi theme selection." 2>&1 | tee -a "$log"
  fi
}

detect_sddm_theme_config_file() {
  local candidate=""
  for candidate in /etc/sddm.conf.d/theme.conf.user /etc/sddm.conf /etc/sddm.conf.d/*.conf; do
    [ -f "$candidate" ] || continue
    if grep -qE '^[[:space:]]*Current[[:space:]]*=' "$candidate" 2>/dev/null; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

detect_sddm_current_theme() {
  local conf_file="$1"
  [ -f "$conf_file" ] || return 1
  awk -F= '
    /^[[:space:]]*Current[[:space:]]*=/ {
      value=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^"|"$/, "", value)
      print value
      exit
    }
  ' "$conf_file"
}

preserve_custom_sddm_configs() {
  local log="$1"
  local hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  local backup_dir
  local backup_hypr_path_primary
  local backup_hypr_path_legacy
  local backup_hypr_path
  local sddm_theme_conf=""
  local sddm_theme=""
  local rel_file=""

  backup_dir=$(get_backup_dirname)
  backup_hypr_path_primary="$hypr_dir-backup-$backup_dir"
  backup_hypr_path_legacy="$hypr_dir-$backup_dir"

  if ! command -v sddm >/dev/null 2>&1; then
    if ! command -v systemctl >/dev/null 2>&1 || ! systemctl list-unit-files 2>/dev/null | grep -q '^sddm\.service'; then
      return 0
    fi
  fi

  sddm_theme_conf="$(detect_sddm_theme_config_file 2>/dev/null || true)"
  [ -n "$sddm_theme_conf" ] || return 0

  sddm_theme="$(detect_sddm_current_theme "$sddm_theme_conf" 2>/dev/null || true)"
  [ -n "$sddm_theme" ] || return 0

  case "$sddm_theme" in
  simple_sddm_2 | simple-sddm | sequoia_2)
    return 0
    ;;
  esac

  for rel_file in scripts/sddm_wallpaper.sh; do
    backup_hypr_path=""
    if [ -f "$backup_hypr_path_primary/$rel_file" ]; then
      backup_hypr_path="$backup_hypr_path_primary"
    elif [ -f "$backup_hypr_path_legacy/$rel_file" ]; then
      backup_hypr_path="$backup_hypr_path_legacy"
    fi
    [ -n "$backup_hypr_path" ] || continue
    mkdir -p "$(dirname "$hypr_dir/$rel_file")"
    cp -f "$backup_hypr_path/$rel_file" "$hypr_dir/$rel_file" 2>&1 | tee -a "$log"
    echo "${NOTE:-[NOTE]} - Preserved existing $rel_file for custom SDDM theme '${sddm_theme}'." 2>&1 | tee -a "$log"
  done
}

# Restore Animations and Monitor Profiles plus key hypr files from backup
restore_hypr_assets() {
  local log="$1"
  local express_mode="$2"

  local HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  local CONFIG_HOME="${XDG_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}"
  local BACKUP_DIR
  BACKUP_DIR=$(get_backup_dirname)
  local BACKUP_HYPR_PATH_PRIMARY="$HYPR_DIR-backup-$BACKUP_DIR"
  local BACKUP_HYPR_PATH_LEGACY="$HYPR_DIR-$BACKUP_DIR"
  local BACKUP_HYPR_PATH="$BACKUP_HYPR_PATH_PRIMARY"

  # Fresh install flow may back up to hypr-<suffix>; prefer that when present.
  if [ -d "$BACKUP_HYPR_PATH_LEGACY" ]; then
    BACKUP_HYPR_PATH="$BACKUP_HYPR_PATH_LEGACY"
  fi

  if [ -d "$BACKUP_HYPR_PATH" ]; then
    local backup_mode="conf"
    if [ -f "$BACKUP_HYPR_PATH/hyprland.lua" ] || [ -f "$CONFIG_HOME/hyprland.lua" ]; then
      backup_mode="lua"
    fi

    # Preserve active Lua entrypoint automatically to avoid dropping users
    # back to hyprland.conf after an upgrade.
    if [ -f "$BACKUP_HYPR_PATH/hyprland.lua" ]; then
      cp -f "$BACKUP_HYPR_PATH/hyprland.lua" "$HYPR_DIR/hyprland.lua" 2>&1 | tee -a "$log"
      echo "${OK:-[OK]} - Restored file: ${MAGENTA:-}hyprland.lua${RESET:-}" 2>&1 | tee -a "$log"
    fi

    if [ "$express_mode" -eq 1 ]; then
      echo "${NOTE:-[NOTE]} Express mode: skipping automatic restoration of animations and monitor profile directories." 2>&1 | tee -a "$log"
      if [ -d "$BACKUP_HYPR_PATH/wallpaper_effects" ]; then
        cp -r "$BACKUP_HYPR_PATH/wallpaper_effects" "$HYPR_DIR/" 2>&1 | tee -a "$log"
        echo "${OK:-[OK]} - Restored directory: ${MAGENTA:-}wallpaper_effects${RESET:-}" 2>&1 | tee -a "$log"
      fi
    else
      echo -e "\n${NOTE:-[NOTE]} Restoring ${SKY_BLUE:-}Animations & Monitor Profiles${RESET:-} into ${YELLOW:-}$HYPR_DIR${RESET:-}..."
      # Preserve runtime wallpaper/monitor state whenever a previous hypr backup exists.
      local DIR_B=("Monitor_Profiles" "animations" "wallpaper_effects")

      for DIR_RESTORE in "${DIR_B[@]}"; do
        local BACKUP_SUBDIR="$BACKUP_HYPR_PATH/$DIR_RESTORE"
        if [ -d "$BACKUP_SUBDIR" ]; then
          cp -r "$BACKUP_SUBDIR" "$HYPR_DIR/" 2>&1 | tee -a "$log"
          echo "${OK:-[OK]} - Restored directory: ${MAGENTA:-}$DIR_RESTORE${RESET:-}" 2>&1 | tee -a "$log"
        fi
      done
    fi

    # Keep monitor/workspace state across upgrades, including express mode.
    if [ "$backup_mode" = "lua" ]; then
      local LUA_USER_DIR="$HYPR_DIR/UserConfigs"
      mkdir -p "$LUA_USER_DIR"

      local BACKUP_LUA_MONITORS=""
      local BACKUP_LUA_WORKSPACES=""
      if [ -f "$BACKUP_HYPR_PATH/UserConfigs/monitors.lua" ]; then
        BACKUP_LUA_MONITORS="$BACKUP_HYPR_PATH/UserConfigs/monitors.lua"
      elif [ -f "$BACKUP_HYPR_PATH/lua/monitors.lua" ]; then
        BACKUP_LUA_MONITORS="$BACKUP_HYPR_PATH/lua/monitors.lua"
      fi
      if [ -f "$BACKUP_HYPR_PATH/UserConfigs/workspaces.lua" ]; then
        BACKUP_LUA_WORKSPACES="$BACKUP_HYPR_PATH/UserConfigs/workspaces.lua"
      elif [ -f "$BACKUP_HYPR_PATH/lua/workspaces.lua" ]; then
        BACKUP_LUA_WORKSPACES="$BACKUP_HYPR_PATH/lua/workspaces.lua"
      fi

      if [ -n "$BACKUP_LUA_MONITORS" ]; then
        cp -f "$BACKUP_LUA_MONITORS" "$LUA_USER_DIR/monitors.lua" 2>&1 | tee -a "$log"
        echo "${OK:-[OK]} - Restored file: ${MAGENTA:-}UserConfigs/monitors.lua${RESET:-}" 2>&1 | tee -a "$log"
      fi
      if [ -n "$BACKUP_LUA_WORKSPACES" ]; then
        cp -f "$BACKUP_LUA_WORKSPACES" "$LUA_USER_DIR/workspaces.lua" 2>&1 | tee -a "$log"
        echo "${OK:-[OK]} - Restored file: ${MAGENTA:-}UserConfigs/workspaces.lua${RESET:-}" 2>&1 | tee -a "$log"
      fi
    else
      local FILE_B=("monitors.conf" "workspaces.conf")
      for FILE_RESTORE in "${FILE_B[@]}"; do
        local BACKUP_FILE="$BACKUP_HYPR_PATH/$FILE_RESTORE"
        if [ -f "$BACKUP_FILE" ]; then
          cp "$BACKUP_FILE" "$HYPR_DIR/$FILE_RESTORE" 2>&1 | tee -a "$log"
          echo "${OK:-[OK]} - Restored file: ${MAGENTA:-}$FILE_RESTORE${RESET:-}" 2>&1 | tee -a "$log"
        fi
      done
    fi
  fi
}

# Helper to extract overlay additions/disables from previous user file vs base
compose_overlay_from_backup() {
  local type="$1" # startup|windowrules
  local base_file="$2"
  local old_user_file="$3"
  local new_user_file="$4"
  local disable_file="$5"

  mkdir -p "$(dirname "$new_user_file")"
  : >"$new_user_file"
  : >"$disable_file"

  if [ "$type" = "startup" ]; then
    grep -E '^\s*exec-once\s*=' "$old_user_file" | sed -E 's/^\s+//;s/\s+$//' | sort -u >"$old_user_file.tmp.exec"
    grep -E '^\s*exec-once\s*=' "$base_file" | sed -E 's/^\s+//;s/\s+$//' | sort -u >"$base_file.tmp.exec"
    comm -23 "$old_user_file.tmp.exec" "$base_file.tmp.exec" >"$new_user_file"
    grep -E '^\s*#\s*exec-once\s*=' "$old_user_file" |
      sed -E 's/^\s*#\s*exec-once\s*=\s*//' |
      sed -E 's/^\s+//;s/\s+$//' |
      grep -Ev '^\$scriptsDir/KeybindsLayoutInit\.sh$' |
      sort -u >"$disable_file"
    rm -f "$old_user_file.tmp.exec" "$base_file.tmp.exec"
  elif [ "$type" = "windowrules" ]; then
    grep -E '^(windowrule|layerrule)\s*=' "$old_user_file" | sed -E 's/^\s+//;s/\s+$//' | sort -u >"$old_user_file.tmp.rules"
    grep -E '^(windowrule|layerrule)\s*=' "$base_file" | sed -E 's/^\s+//;s/\s+$//' | sort -u >"$base_file.tmp.rules"
    comm -23 "$old_user_file.tmp.rules" "$base_file.tmp.rules" >"$new_user_file"
    grep -E '^\s*#\s*(windowrule|layerrule)\s*=' "$old_user_file" | sed -E 's/^\s*#\s*//' | sed -E 's/^\s+//;s/\s+$//' | sort -u >"$disable_file"
    rm -f "$old_user_file.tmp.rules" "$base_file.tmp.rules"
  fi
}

cleanup_duplicate_userconfigs() {
  local current_version="$1"
  local log="$2"

  if [ -z "$current_version" ]; then
    return
  fi

  # Run de-dupe only for existing installs up to and including v2.3.18.
  # For v2.3.19 and newer, UserConfigs should be left as-is to avoid
  # removing user modifications.
  if version_gte "$current_version" "2.3.19"; then
    echo "${INFO:-[INFO]} Skipping UserConfigs duplicate cleanup for detected version v$current_version (>= 2.3.19)." 2>&1 | tee -a "$log"
    return
  fi

  echo "${INFO:-[INFO]} Running UserConfigs duplicate cleanup for detected version v$current_version (<= 2.3.18)." 2>&1 | tee -a "$log"

  local HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  local BASE_DIR="$HYPR_DIR/configs"
  local USER_DIR="$HYPR_DIR/UserConfigs"

  local STARTUP_BASE="$BASE_DIR/Startup_Apps.conf"
  local STARTUP_USER="$USER_DIR/Startup_Apps.conf"
  local WINDOW_BASE="$BASE_DIR/WindowRules.conf"
  local WINDOW_USER="$USER_DIR/WindowRules.conf"
  local KEYBINDS_BASE="$BASE_DIR/Keybinds.conf"
  local KEYBINDS_USER="$USER_DIR/UserKeybinds.conf"

  # Startup_Apps: strip exec-once lines from UserConfigs that are exact
  # duplicates of the base Startup_Apps.conf.
  if [ -f "$STARTUP_BASE" ] && [ -f "$STARTUP_USER" ]; then
    local tmp_startup
    local backup_startup
    backup_startup="$STARTUP_USER.backup-dupfix-$(date +%Y%m%d-%H%M%S)"
    tmp_startup=$(mktemp)
    awk '
      function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      FNR==NR {
        if ($0 ~ /^[ \t]*exec-once[ \t]*=/) {
          line=trim($0)
          base[line]=1
        }
        next
      }
      {
        if ($0 ~ /^[ \t]*exec-once[ \t]*=/) {
          line=trim($0)
          if (line in base) next
        }
        print
      }
    ' "$STARTUP_BASE" "$STARTUP_USER" >"$tmp_startup"
    if ! cmp -s "$STARTUP_USER" "$tmp_startup"; then
      cp "$STARTUP_USER" "$backup_startup"
      mv "$tmp_startup" "$STARTUP_USER"
      echo "${NOTE:-[NOTE]} - Removed duplicate Startup_Apps entries matching base config." 2>&1 | tee -a "$log"
    else
      rm -f "$tmp_startup"
    fi
  fi

  # WindowRules: strip windowrule/layerrule lines from UserConfigs that
  # are exact duplicates of the base WindowRules.conf.
  if [ -f "$WINDOW_BASE" ] && [ -f "$WINDOW_USER" ]; then
    local tmp_window
    local backup_window
    backup_window="$WINDOW_USER.backup-dupfix-$(date +%Y%m%d-%H%M%S)"
    tmp_window=$(mktemp)
    awk '
      function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      FNR==NR {
        if ($0 ~ /^[ \t]*(windowrule|layerrule)[ \t]*=/) {
          line=trim($0)
          base[line]=1
        }
        next
      }
      {
        if ($0 ~ /^[ \t]*(windowrule|layerrule)[ \t]*=/) {
          line=trim($0)
          if (line in base) next
        }
        print
      }
    ' "$WINDOW_BASE" "$WINDOW_USER" >"$tmp_window"
    if ! cmp -s "$WINDOW_USER" "$tmp_window"; then
      cp "$WINDOW_USER" "$backup_window"
      mv "$tmp_window" "$WINDOW_USER"
      echo "${NOTE:-[NOTE]} - Removed duplicate WindowRules entries matching base config." 2>&1 | tee -a "$log"
    else
      rm -f "$tmp_window"
    fi
  fi

  # Keybinds: strip bind* lines from UserKeybinds.conf that are exact
  # duplicates of the base Keybinds.conf. Comments and unbinds are kept.
  if [ -f "$KEYBINDS_BASE" ] && [ -f "$KEYBINDS_USER" ]; then
    local tmp_keybinds
    local backup_keybinds
    backup_keybinds="$KEYBINDS_USER.backup-dupfix-$(date +%Y%m%d-%H%M%S)"
    tmp_keybinds=$(mktemp)
    awk '
      function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      FNR==NR {
        # Match any Hyprland bind variant: bindd, bindmd, bindld, binded,
        # bindlnd, bindeld, etc.
        if ($0 ~ /^[ \t]*bind[a-z]*[ \t]*=/) {
          line=trim($0)
          base[line]=1
        }
        next
      }
      {
        if ($0 ~ /^[ \t]*bind[a-z]*[ \t]*=/) {
          line=trim($0)
          if (line in base) next
        }
        print
      }
    ' "$KEYBINDS_BASE" "$KEYBINDS_USER" >"$tmp_keybinds"
    if ! cmp -s "$KEYBINDS_USER" "$tmp_keybinds"; then
      cp "$KEYBINDS_USER" "$backup_keybinds"
      mv "$tmp_keybinds" "$KEYBINDS_USER"
      echo "${NOTE:-[NOTE]} - Removed duplicate UserKeybinds entries matching base Keybinds.conf." 2>&1 | tee -a "$log"
    else
      rm -f "$tmp_keybinds"
    fi
  fi
}
restore_user_configs() {
  local log="$1"
  local express_mode="$2"
  local old_version="$3"

  local DIRPATH="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  local BACKUP_DIR
  BACKUP_DIR=$(get_backup_dirname)
  local BACKUP_DIR_PATH_PRIMARY="$DIRPATH-backup-$BACKUP_DIR/UserConfigs"
  local BACKUP_DIR_PATH_LEGACY="$DIRPATH-$BACKUP_DIR/UserConfigs"
  local BACKUP_CONFIGS_PATH_PRIMARY="$DIRPATH-backup-$BACKUP_DIR/configs"
  local BACKUP_CONFIGS_PATH_LEGACY="$DIRPATH-$BACKUP_DIR/configs"
  local BACKUP_DIR_PATH="$BACKUP_DIR_PATH_PRIMARY"
  local BACKUP_CONFIGS_PATH="$BACKUP_CONFIGS_PATH_PRIMARY"

  if [ -z "$BACKUP_DIR" ]; then
    echo "${ERROR:-[ERROR]} - Backup directory name is empty. Exiting." 2>&1 | tee -a "$log"
    exit 1
  fi

  if [ "${RUN_MODE:-}" = "install" ]; then
    if [ -d "$BACKUP_DIR_PATH_LEGACY" ] || [ -d "$BACKUP_DIR_PATH_PRIMARY" ]; then
      echo "${NOTE:-[NOTE]} Preserving existing UserConfigs directory during install." 2>&1 | tee -a "$log"
      if [ -d "$BACKUP_DIR_PATH_LEGACY" ]; then
        rsync -a "$BACKUP_DIR_PATH_LEGACY/" "$DIRPATH/UserConfigs/" 2>&1 | tee -a "$log"
      fi
      if [ -d "$BACKUP_DIR_PATH_PRIMARY" ]; then
        rsync -a "$BACKUP_DIR_PATH_PRIMARY/" "$DIRPATH/UserConfigs/" 2>&1 | tee -a "$log"
      fi
      echo "${OK:-[OK]} - UserConfigs directory preserved." 2>&1 | tee -a "$log"
    fi
    return
  fi
  if [ ! -d "$BACKUP_DIR_PATH" ] && [ -d "$BACKUP_DIR_PATH_LEGACY" ]; then
    BACKUP_DIR_PATH="$BACKUP_DIR_PATH_LEGACY"
  fi
  if [ ! -d "$BACKUP_CONFIGS_PATH" ] && [ -d "$BACKUP_CONFIGS_PATH_LEGACY" ]; then
    BACKUP_CONFIGS_PATH="$BACKUP_CONFIGS_PATH_LEGACY"
  fi

  if [ -d "$BACKUP_DIR_PATH" ]; then
    local VERSION_FILE
    VERSION_FILE=$(find "$DIRPATH" -maxdepth 1 -name "v*.*.*" | head -n 1)
    local CURRENT_VERSION="999.9.9"
    if [ -n "$old_version" ]; then
      CURRENT_VERSION="$old_version"
    fi

    local TARGET_VERSION="2.3.19"
    local AUTO_RESTORE=0
    if version_gte "$CURRENT_VERSION" "2.3.18"; then
      AUTO_RESTORE=1
    fi

    echo -e "${NOTE:-[NOTE]} Restoring previous ${MAGENTA:-}User-Configs${RESET:-}... " 2>&1 | tee -a "$log"
    printf "${WARNING:-}\\
    █▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█\\n\\
            NOTES for RESTORING PREVIOUS CONFIGS\\n\\
    █▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄█\\n\\n\\
    The 'UserConfigs' directory is for all your personal settings.\\n\\
    Files in this directory will override the default configurations,\\n\\
    so your customizations are not lost when you update.\\n\\
" >&2

    if version_gte "$CURRENT_VERSION" "$TARGET_VERSION"; then
      if [ "$express_mode" -eq 1 ] || [ "$AUTO_RESTORE" -eq 1 ]; then
        echo "${NOTE:-[NOTE]} Restoring UserConfigs directory automatically." 2>&1 | tee -a "$log"
        rsync -a "$BACKUP_DIR_PATH/" "$DIRPATH/UserConfigs/" 2>&1 | tee -a "$log"
        echo "${OK:-[OK]} - UserConfigs directory restored." 2>&1 | tee -a "$log"
      else
        read -r -p "${CAT:-[ACTION]} Do you want to restore your previous UserConfigs directory? (Y/n): " restore_userconfigs_dir
        if [[ "$restore_userconfigs_dir" != [Nn]* ]]; then
          echo "${NOTE:-[NOTE]} Restoring UserConfigs directory..." 2>&1 | tee -a "$log"
          rsync -a "$BACKUP_DIR_PATH/" "$DIRPATH/UserConfigs/" 2>&1 | tee -a "$log"
          echo "${OK:-[OK]} - UserConfigs directory restored." 2>&1 | tee -a "$log"
        else
          echo "${NOTE:-[NOTE]} - Skipped restoring UserConfigs." 2>&1 | tee -a "$log"
        fi
      fi
    else
      echo -e "${NOTE:-[NOTE]} Detected version ${YELLOW:-}v$CURRENT_VERSION${RESET:-} (older than v$TARGET_VERSION). Using legacy restoration mode." 2>&1 | tee -a "$log"

      local FILES_TO_RESTORE=(
        "01-UserDefaults.conf"
        "ENVariables.conf"
        "LaptopDisplay.conf"
        "Laptops.conf"
        "monitors.lua"
        "Startup_Apps.conf"
        "UserDecorations.conf"
        "UserAnimations.conf"
        "UserKeybinds.conf"
        "UserSettings.conf"
        "workspaces.lua"
        "WindowRules.conf"
      )

      for FILE_NAME in "${FILES_TO_RESTORE[@]}"; do
        local BACKUP_FILE="$BACKUP_DIR_PATH/$FILE_NAME"
        if [ -f "$BACKUP_FILE" ]; then
          if [ "$FILE_NAME" = "Startup_Apps.conf" ]; then
            compose_overlay_from_backup "startup" "$DIRPATH/configs/Startup_Apps.conf" "$BACKUP_FILE" "$DIRPATH/UserConfigs/Startup_Apps.conf" "$DIRPATH/UserConfigs/Startup_Apps.disable"
            echo "${OK:-[OK]} - Migrated overlay for ${YELLOW:-}$FILE_NAME${RESET:-}" 2>&1 | tee -a "$log"
            continue
          fi
          if [ "$FILE_NAME" = "WindowRules.conf" ]; then
            compose_overlay_from_backup "windowrules" "$DIRPATH/configs/WindowRules.conf" "$BACKUP_FILE" "$DIRPATH/UserConfigs/WindowRules.conf" "$DIRPATH/UserConfigs/WindowRules.disable"
            echo "${OK:-[OK]} - Migrated overlay for ${YELLOW:-}$FILE_NAME${RESET:-}" 2>&1 | tee -a "$log"
            continue
          fi
          if [ "$express_mode" -eq 1 ] || [ "$AUTO_RESTORE" -eq 1 ]; then
            if cp "$BACKUP_FILE" "$DIRPATH/UserConfigs/$FILE_NAME"; then
              echo "${OK:-[OK]} - $FILE_NAME restored!" 2>&1 | tee -a "$log"
            else
              echo "${ERROR:-[ERROR]} - Failed to restore $FILE_NAME!" 2>&1 | tee -a "$log"
            fi
          else
            printf "\n${INFO:-[INFO]} Found ${YELLOW:-}$FILE_NAME${RESET:-} in hypr backup...\n"
            read -r -p "${CAT:-[ACTION]} Do you want to restore ${YELLOW:-}$FILE_NAME${RESET:-} from backup? (Y/n): " file_restore

            if [[ "$file_restore" != [Nn]* ]]; then
              if cp "$BACKUP_FILE" "$DIRPATH/UserConfigs/$FILE_NAME"; then
                echo "${OK:-[OK]} - $FILE_NAME restored!" 2>&1 | tee -a "$log"
              else
                echo "${ERROR:-[ERROR]} - Failed to restore $FILE_NAME!" 2>&1 | tee -a "$log"
              fi
            else
              echo "${NOTE:-[NOTE]} - Skipped restoring $FILE_NAME." 2>&1 | tee -a "$log"
            fi
          fi
        fi
      done
    fi
  fi

  if [ -d "$BACKUP_CONFIGS_PATH" ]; then
    local restored_system_lua=0
    local lua_file
    mkdir -p "$DIRPATH/configs"
    while IFS= read -r -d '' lua_file; do
      cp -f "$lua_file" "$DIRPATH/configs/"
      restored_system_lua=1
    done < <(find "$BACKUP_CONFIGS_PATH" -maxdepth 1 -type f -name 'system_*.lua' -print0)
    if [ "$restored_system_lua" -eq 1 ]; then
      echo "${OK:-[OK]} - Restored migrated system Lua overlays to $DIRPATH/configs." 2>&1 | tee -a "$log"
    fi
  fi

  # Always run de-dupe based on the installed dotfiles version so that
  # express mode and standard mode behave consistently. Prefer the
  # pre-upgrade version (old_version) if provided so we still clean up
  # legacy duplicates when upgrading to a newer release that no longer
  # needs the fix.
  local detected_version="$old_version"
  if [ -z "$detected_version" ]; then
    detected_version=$(get_installed_dotfiles_version)
  fi
  if [ -n "$detected_version" ]; then
    cleanup_duplicate_userconfigs "$detected_version" "$log"
  fi
}

restore_user_scripts() {
  local log="$1"
  local express_mode="$2"

  local DIRSHPATH="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  local BACKUP_DIR
  BACKUP_DIR=$(get_backup_dirname)
  local BACKUP_DIR_PATH_S="$DIRSHPATH-backup-$BACKUP_DIR/UserScripts"
  local SCRIPTS_TO_RESTORE=("RofiBeats.sh" "Weather.py" "Weather.sh")

  if [ -d "$BACKUP_DIR_PATH_S" ] && [ "$express_mode" -eq 1 ]; then
    echo "${NOTE:-[NOTE]} Express mode: skipping UserScripts restoration prompts." 2>&1 | tee -a "$log"
    return
  fi

  if [ -d "$BACKUP_DIR_PATH_S" ] && [ "$express_mode" -eq 0 ]; then
    echo -e "${NOTE:-[NOTE]} Restoring previous ${MAGENTA:-}User-Scripts${RESET:-}..." 2>&1 | tee -a "$log"

    for SCRIPT_NAME in "${SCRIPTS_TO_RESTORE[@]}"; do
      local BACKUP_SCRIPT="$BACKUP_DIR_PATH_S/$SCRIPT_NAME"
      if [ -f "$BACKUP_SCRIPT" ]; then
        printf "\n${INFO:-[INFO]} Found ${YELLOW:-}$SCRIPT_NAME${RESET:-} in hypr backup...\n"
        read -r -p "${CAT:-[ACTION]} Do you want to restore ${YELLOW:-}$SCRIPT_NAME${RESET:-} from backup? (y/N): " script_restore

        if [[ "$script_restore" == [Yy]* ]]; then
          if cp "$BACKUP_SCRIPT" "$DIRSHPATH/UserScripts/$SCRIPT_NAME"; then
            echo "${OK:-[OK]} - $SCRIPT_NAME restored!" 2>&1 | tee -a "$log"
          else
            echo "${ERROR:-[ERROR]} - Failed to restore $SCRIPT_NAME!" 2>&1 | tee -a "$log"
          fi
        else
          echo "${NOTE:-[NOTE]} - Skipped restoring $SCRIPT_NAME." 2>&1 | tee -a "$log"
        fi
      fi
    done
  fi
}

restore_terminal_configs() {
  local log="$1"
  echo "${NOTE:-[NOTE]} - Terminal config restore prompts removed; UserConfigs now preserves kitty/ghostty settings." 2>&1 | tee -a "$log"
}
restore_hypr_files() {
  local log="$1"
  local express_mode="$2"

  local DIRPATH="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  local BACKUP_DIR
  BACKUP_DIR=$(get_backup_dirname)
  local BACKUP_DIR_PATH_F_PRIMARY="$DIRPATH-backup-$BACKUP_DIR"
  local BACKUP_DIR_PATH_F_LEGACY="$DIRPATH-$BACKUP_DIR"
  local FILES_TO_PRESERVE=("hyprlock.conf" "hypridle.conf")
  local FILE_RESTORE

  # keep signature compatibility; prompts for these files are removed
  : "$express_mode"
  if [ ! -d "$BACKUP_DIR_PATH_F_PRIMARY" ] && [ ! -d "$BACKUP_DIR_PATH_F_LEGACY" ]; then
    return
  fi

  for FILE_RESTORE in "${FILES_TO_PRESERVE[@]}"; do
    local BACKUP_FILE="$BACKUP_DIR_PATH_F_PRIMARY/$FILE_RESTORE"
    if [ ! -f "$BACKUP_FILE" ] && [ -f "$BACKUP_DIR_PATH_F_LEGACY/$FILE_RESTORE" ]; then
      BACKUP_FILE="$BACKUP_DIR_PATH_F_LEGACY/$FILE_RESTORE"
    fi
    if [ -f "$BACKUP_FILE" ]; then
      if cp -f "$BACKUP_FILE" "$DIRPATH/$FILE_RESTORE"; then
        echo "${OK:-[OK]} - Preserved existing $FILE_RESTORE from backup." 2>&1 | tee -a "$log"
      else
        echo "${ERROR:-[ERROR]} - Failed to preserve existing $FILE_RESTORE from backup." 2>&1 | tee -a "$log"
      fi
    fi
  done
}
