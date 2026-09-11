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
  local run_mode="${2:-${RUN_MODE:-}}"
  local base="${DOTFILES_DIR:-.}"
  local dirs="fastfetch kitty swaync"
  for DIR2 in $dirs; do
    local DIRPATH="${XDG_CONFIG_HOME:-$HOME/.config}/$DIR2"
    if [ -d "$DIRPATH" ]; then
      if [ "$run_mode" = "express" ]; then
        echo -e "${NOTE:-[NOTE]} - Express mode: keeping existing ${YELLOW:-}$DIR2${RESET:-} config." 2>&1 | tee -a "$log"
        continue
      fi
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

  # Handle ~/.config/rofi: backup existing and ensure an empty directory exists
  local rofi_dir="${XDG_CONFIG_HOME:-$HOME/.config}/rofi"
  if [ -d "$rofi_dir" ]; then
    if [ -n "$(ls -A "$rofi_dir" 2>/dev/null)" ]; then
      local BACKUP_DIR
      BACKUP_DIR=$(get_backup_dirname)
      mv "$rofi_dir" "$rofi_dir-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
      echo -e "${NOTE:-[NOTE]} - Backed up rofi to $rofi_dir-backup-$BACKUP_DIR." 2>&1 | tee -a "$log"
      mkdir -p "$rofi_dir"
      echo -e "${OK:-[OK]} - Created empty rofi directory at $rofi_dir." 2>&1 | tee -a "$log"
      if [ -d "$rofi_dir-backup-$BACKUP_DIR/themes" ]; then
        mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/themes"
        for file in "$rofi_dir-backup-$BACKUP_DIR/themes"/*; do
          [ -e "$file" ] || continue
          cp -n "$file" "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/themes/" >>"$log" 2>&1 || true
        done || true
      fi
      if [ -f "$rofi_dir-backup-$BACKUP_DIR/0-shared-fonts.rasi" ] && [ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/0-shared-fonts.rasi" ]; then
        cp "$rofi_dir-backup-$BACKUP_DIR/0-shared-fonts.rasi" "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/0-shared-fonts.rasi" >>"$log" 2>&1 || true
      fi
    fi
  else
    mkdir -p "$rofi_dir"
  fi
}

# Restore symlink targets and custom user-added configs/styles from a waybar
# backup directory into the freshly-copied waybar dir. Shared by both the
# normal in-place upgrade path and the legacy ~/.config/waybar migration path.
_restore_waybar_customizations() {
  local new_dir="$1"
  local backup_dir="$2"
  local file dir symlink symlink_target target_name target_file target_dir BACKUP_FILEw

  for file in "config" "style.css"; do
    symlink="$backup_dir/$file"
    target_file="$new_dir/$file"
    if [ -L "$symlink" ]; then
      symlink_target=$(readlink "$symlink")
      target_name=$(basename "$symlink_target")
      # Normalize legacy names if needed
      case "$target_name" in
        "[TOP] Default"|"[TOP] Default Laptop"|"[TOP] Default (old v"*)
          target_name="${target_name//\[TOP\] /TOP-}"
          target_name="${target_name// Laptop/-Laptop}"
          target_name="${target_name// (old v/-old-v}"
          target_name="${target_name//)/}"
          ;;
        "[BOT] Default"|"[BOT] Default Laptop")
          target_name="${target_name//\[BOT\] /BOT-}"
          target_name="${target_name// Laptop/-Laptop}"
          ;;
      esac
      if [ "$file" = "config" ] && [ -f "$new_dir/configs/$target_name" ]; then
        rm -f "$target_file" && ln -sf "$new_dir/configs/$target_name" "$target_file"
      elif [ "$file" = "style.css" ] && [ -f "$new_dir/style/$target_name" ]; then
        rm -f "$target_file" && ln -sf "$new_dir/style/$target_name" "$target_file"
      fi
    elif [ -f "$symlink" ]; then
      # If backup was a regular file with stale includes, patch them in-place
      rm -f "$target_file" && cp -f "$symlink" "$target_file"
      if [ "$file" = "config" ]; then
        sed -i 's#\$HOME/\.config/waybar/#$HOME/.config/hypr/waybar/#g; s#~/\.config/waybar/#~/.config/hypr/waybar/#g' "$target_file" 2>/dev/null || true
      elif [ "$file" = "style.css" ]; then
        sed -i -E 's#(@import[[:space:]]*["'"'"'])\.\./\.\./\.config/waybar/wallust/colors-waybar\.css(["'"'"'])#\1../../../.config/hypr/waybar/wallust/colors-waybar.css\2#g; s#\.config/waybar/#.config/hypr/waybar/#g' "$target_file" 2>/dev/null || true
      fi
    fi
  done
  for dir in "$backup_dir/configs"/*; do
    [ -e "$dir" ] || continue
    if [ -d "$dir" ]; then
      target_dir="$new_dir/configs/$(basename "$dir")"
      [ -d "$target_dir" ] || cp -r "$dir" "$new_dir/configs/"
    fi
  done
  for file in "$backup_dir/configs"/*; do
    [ -e "$file" ] || continue
    target_file="$new_dir/configs/$(basename "$file")"
    if [ ! -e "$target_file" ]; then
      cp "$file" "$new_dir/configs/"
      sed -i 's#\$HOME/\.config/waybar/#$HOME/.config/hypr/waybar/#g; s#~/\.config/waybar/#~/.config/hypr/waybar/#g' "$target_file" 2>/dev/null || true
    fi
  done || true
  for file in "$backup_dir/style"/*; do
    [ -e "$file" ] || continue
    if [ -d "$file" ]; then
      target_dir="$new_dir/style/$(basename "$file")"
      [ -d "$target_dir" ] || cp -r "$file" "$new_dir/style/"
    else
      target_file="$new_dir/style/$(basename "$file")"
      if [ ! -e "$target_file" ]; then
        cp "$file" "$new_dir/style/"
        sed -i -E 's#(@import[[:space:]]*["'"'"'])\.\./\.\./\.config/waybar/wallust/colors-waybar\.css(["'"'"'])#\1../../../.config/hypr/waybar/wallust/colors-waybar.css\2#g; s#\.config/waybar/#.config/hypr/waybar/#g' "$target_file" 2>/dev/null || true
      fi
    fi
  done || true
  BACKUP_FILEw="$backup_dir/UserModules"
  [ -f "$BACKUP_FILEw" ] && cp -f "$BACKUP_FILEw" "$new_dir/UserModules"

  # Ensure config and style.css exist and are valid symlinks; if broken or missing, point to defaults
  if [ ! -e "$new_dir/config" ]; then
    local chassis
    chassis="$(detect_waybar_config 2>/dev/null || echo "desktop")"
    local d_cfg="$new_dir/configs/TOP-Default"
    [ "$chassis" = "laptop" ] && d_cfg="$new_dir/configs/TOP-Default-Laptop"
    [ -f "$d_cfg" ] && rm -f "$new_dir/config" && ln -sf "$d_cfg" "$new_dir/config"
  fi
  if [ ! -e "$new_dir/style.css" ]; then
    local d_stl="$new_dir/style/Extra-Prismatic-Glow.css"
    [ -f "$d_stl" ] && rm -f "$new_dir/style.css" && ln -sf "$d_stl" "$new_dir/style.css"
  fi
}

# Detect a waybar directory whose configs/modules/styles still reference the
# pre-migration "$HOME/.config/waybar/" path, or whose config/style.css links
# are broken, missing, or pointing to stale locations.
_waybar_dir_has_stale_paths() {
  local dir="$1"
  [ -d "$dir" ] || return 1

  # 1. Check if config or style.css symlinks point to legacy path or are broken
  for link in "$dir/config" "$dir/style.css"; do
    if [ -L "$link" ]; then
      local tgt
      tgt="$(readlink "$link" 2>/dev/null || true)"
      if [[ "$tgt" == *".config/waybar"* ]] || [ ! -e "$link" ]; then
        return 0
      fi
    elif [ -f "$link" ]; then
      # Regular file with stale includes is stale
      if grep -rq '\.config/waybar/' "$link" 2>/dev/null; then
        return 0
      fi
    elif [ ! -e "$link" ]; then
      return 0
    fi
  done

  # 2. Check if any file content inside directory has stale .config/waybar references
  if grep -rq '\.config/waybar/' "$dir" 2>/dev/null; then
    return 0
  fi

  return 1
}

copy_waybar() {
  local log="$1"
  local run_mode="${2:-${RUN_MODE:-}}"
  local base="${DOTFILES_DIR:-.}"
  local DIRW="waybar"
  local OLD_DIRPATHw="${XDG_CONFIG_HOME:-$HOME/.config}/$DIRW"
  local DIRPATHw="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/$DIRW"

  mkdir -p "$(dirname "$DIRPATHw")"

  # One-time migration: a pre-migration install has waybar at the legacy
  # top-level path (~/.config/waybar), but the new hypr-owned path
  # (~/.config/hypr/waybar) does not exist yet. Its configs/modules/styles
  # always reference the old "$HOME/.config/waybar/" path (correct for where
  # they used to live), which breaks the moment they're relocated to a new
  # parent directory -- so always back up, install a fresh repo copy, and
  # restore customizations on top. A bare relocate is never safe here.
  if [ -d "$OLD_DIRPATHw" ] && [ ! -d "$DIRPATHw" ]; then
    echo -e "${NOTE:-[NOTE]} - Detected legacy ${YELLOW:-}$OLD_DIRPATHw${RESET:-}; migrating it to ${YELLOW:-}$DIRPATHw${RESET:-}." 2>&1 | tee -a "$log"
    BACKUP_DIR=$(get_backup_dirname)
    cp -r "$OLD_DIRPATHw" "$OLD_DIRPATHw-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
    echo -e "${NOTE:-[NOTE]} - Backed up $DIRW to $OLD_DIRPATHw-backup-$BACKUP_DIR." 2>&1 | tee -a "$log"
    rm -rf "$OLD_DIRPATHw"
    cp -r "$base/config/hypr/$DIRW" "$DIRPATHw" 2>&1 | tee -a "$log"
    _restore_waybar_customizations "$DIRPATHw" "$OLD_DIRPATHw-backup-$BACKUP_DIR"
    echo -e "${OK:-[OK]} - Migrated ${YELLOW:-}$DIRW${RESET:-} config to ${YELLOW:-}$DIRPATHw${RESET:-}." 2>&1 | tee -a "$log"
    return 0
  fi

  if [ -d "$DIRPATHw" ]; then
    # Stale check runs first and bypasses both the express "keep existing"
    # shortcut and the interactive y/n prompt below: a directory with broken
    # path references (e.g. left behind by an earlier/interrupted copy of
    # this dotfiles version) is not something either mode should preserve.
    if _waybar_dir_has_stale_paths "$DIRPATHw"; then
      echo -e "${WARN:-[WARN]} - ${YELLOW:-}$DIRPATHw${RESET:-} still contains pre-migration path references (\$HOME/.config/waybar/...) from an earlier/interrupted copy; module includes and CSS imports are broken as a result. Repairing automatically." 2>&1 | tee -a "$log"
      BACKUP_DIR=$(get_backup_dirname)
      cp -r "$DIRPATHw" "$DIRPATHw-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
      echo -e "${NOTE:-[NOTE]} - Backed up $DIRW to $DIRPATHw-backup-$BACKUP_DIR." 2>&1 | tee -a "$log"
      rm -rf "$DIRPATHw" && cp -r "$base/config/hypr/$DIRW" "$DIRPATHw" 2>&1 | tee -a "$log"
      _restore_waybar_customizations "$DIRPATHw" "$DIRPATHw-backup-$BACKUP_DIR"
      echo -e "${OK:-[OK]} - Repaired stale ${YELLOW:-}$DIRW${RESET:-} config at ${YELLOW:-}$DIRPATHw${RESET:-} (runs regardless of express/upgrade mode since the old content was broken, not a preference)." 2>&1 | tee -a "$log"
      return 0
    fi

    if [ "$run_mode" = "express" ]; then
      echo -e "${NOTE:-[NOTE]} - Express mode: keeping existing ${YELLOW:-}$DIRW${RESET:-} config." 2>&1 | tee -a "$log"
      return 0
    fi
    while true; do
      echo -n "${CAT:-[ACTION]} Do you want to replace ${YELLOW:-}$DIRW${RESET:-} config? (y/n): "
      read DIR1_CHOICE
      case "$DIR1_CHOICE" in
      [Yy]*)
        BACKUP_DIR=$(get_backup_dirname)
        cp -r "$DIRPATHw" "$DIRPATHw-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
        echo -e "${NOTE:-[NOTE]} - Backed up $DIRW to $DIRPATHw-backup-$BACKUP_DIR." 2>&1 | tee -a "$log"
        rm -rf "$DIRPATHw" && cp -r "$base/config/hypr/$DIRW" "$DIRPATHw" 2>&1 | tee -a "$log"
        _restore_waybar_customizations "$DIRPATHw" "$DIRPATHw-backup-$BACKUP_DIR"
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
    cp -r "$base/config/hypr/$DIRW" "$DIRPATHw" 2>&1 | tee -a "$log"
    echo -e "${OK:-[OK]} - Copy completed for ${YELLOW:-}$DIRW${RESET:-}" 2>&1 | tee -a "$log"
  fi
}

copy_phase2() {
  local log="$1"
  local base="${DOTFILES_DIR:-.}"
  local DIR="btop cava hypr Kvantum nwg-dock-hyprland qt5ct qt6ct starship swappy wlogout yazi"

  # copy_waybar() (called before copy_phase2) already placed the final
  # waybar content at ~/.config/hypr/waybar (fresh copy, or backed-up and
  # restored from an existing/legacy install). Since waybar now lives
  # underneath hypr/, the blanket "hypr" backup+recopy below would otherwise
  # discard that work and replace it with an untouched repo copy. Stash it
  # aside and put it back once the hypr copy is done.
  local hypr_waybar_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/waybar"
  local hypr_waybar_stash=""
  if [ -d "$hypr_waybar_dir" ]; then
    hypr_waybar_stash="$(mktemp -d "${TMPDIR:-/tmp}/kooldots-waybar-stash.XXXXXX")"
    mv "$hypr_waybar_dir" "$hypr_waybar_stash/waybar" 2>&1 | tee -a "$log"
  fi

  for DIR_NAME in $DIR; do
    local DIRPATH="${XDG_CONFIG_HOME:-$HOME/.config}/$DIR_NAME"
    if [ -d "$DIRPATH" ]; then
      echo -e "\n${NOTE:-[NOTE]} - Config for ${YELLOW:-}$DIR_NAME${RESET:-} found, attempting to back up."
      BACKUP_DIR=$(get_backup_dirname)
      mv "$DIRPATH" "$DIRPATH-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
    fi
    if [ -d "$base/config/$DIR_NAME" ]; then
      cp -r "$base/config/$DIR_NAME/" "${XDG_CONFIG_HOME:-$HOME/.config}/$DIR_NAME" 2>&1 | tee -a "$log"
      if [ "$DIR_NAME" = "gtk-3.0" ] && [ -n "$BACKUP_DIR" ] && [ -f "$DIRPATH-backup-$BACKUP_DIR/settings.ini" ]; then
        cp -n "$DIRPATH-backup-$BACKUP_DIR/settings.ini" "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini" 2>/dev/null || true
      fi
      echo "${OK:-[OK]} - Copy of config for ${YELLOW:-}$DIR_NAME${RESET:-} completed!" 2>&1 | tee -a "$log"
    else
      echo "${ERROR:-[ERROR]} - Directory config/$DIR_NAME does not exist to copy." 2>&1 | tee -a "$log"
    fi
  done

  if [ -n "$hypr_waybar_stash" ] && [ -d "$hypr_waybar_stash/waybar" ]; then
    rm -rf "$hypr_waybar_dir"
    mv "$hypr_waybar_stash/waybar" "$hypr_waybar_dir" 2>&1 | tee -a "$log"
    rmdir "$hypr_waybar_stash" 2>/dev/null || true
    echo -e "${NOTE:-[NOTE]} - Restored ${YELLOW:-}waybar${RESET:-} configuration (managed separately by copy_waybar())." 2>&1 | tee -a "$log"
  fi

  # Handle ~/.config/wallust like rofi migration:
  # keep wallust data under ~/.config/hypr/wallust and leave ~/.config/wallust empty
  local wallust_dir="${XDG_CONFIG_HOME:-$HOME/.config}/wallust"
  local hypr_wallust_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallust"
  if [ -d "$wallust_dir" ]; then
    if [ -n "$(ls -A "$wallust_dir" 2>/dev/null)" ]; then
      local BACKUP_DIR
      BACKUP_DIR=$(get_backup_dirname)
      mv "$wallust_dir" "$wallust_dir-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
      echo -e "${NOTE:-[NOTE]} - Backed up wallust to $wallust_dir-backup-$BACKUP_DIR." 2>&1 | tee -a "$log"
      mkdir -p "$wallust_dir" "$hypr_wallust_dir"
      rsync -a --ignore-existing "$wallust_dir-backup-$BACKUP_DIR/" "$hypr_wallust_dir/" 2>&1 | tee -a "$log" || true
      echo -e "${OK:-[OK]} - Migrated existing wallust files to ${YELLOW:-}$hypr_wallust_dir${RESET:-} and left ${YELLOW:-}$wallust_dir${RESET:-} empty." 2>&1 | tee -a "$log"
    fi
  else
    mkdir -p "$wallust_dir"
  fi
  # Clean up stale GTK-3 Wallust css overrides if present from older versions
  local gtk3_dir="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0"
  if [ -f "$gtk3_dir/colors-wallust.css" ]; then
    rm -f "$gtk3_dir/colors-wallust.css"
    if [ -f "$gtk3_dir/gtk.css" ]; then
      if ! grep -Ev '^[[:space:]]*(/\*.*\*/|@import[[:space:]]+[\x27"]colors-wallust\.css[\x27"];|[[:space:]]*)$' "$gtk3_dir/gtk.css" >/dev/null 2>&1; then
        rm -f "$gtk3_dir/gtk.css"
      else
        sed -i "/@import[[:space:]]*['\"]colors-wallust\.css['\"];/d" "$gtk3_dir/gtk.css" 2>/dev/null || true
      fi
    fi
  fi

  install_terminal_configs "$log"
}

# Fresh install default: enable Hyprland Lua entrypoint (next release is Lua-only).
enable_fresh_install_lua_config() {
  local log="${1:-/dev/null}"
  local hypr_dir
  local src_entry
  local base="${DOTFILES_DIR:-.}"
  hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  src_entry="$base/config/hypr/hyprland.lua"
  if [ ! -f "$src_entry" ] && [ -f "$base/config/hypr/hyprland.lua.disable" ]; then
    src_entry="$base/config/hypr/hyprland.lua.disable"
  fi

  mkdir -p "$hypr_dir"

  if [ -f "$hypr_dir/hyprland.lua" ]; then
    rm -f "$hypr_dir/hyprland.lua.disable" 2>/dev/null || true
    echo "${OK:-[OK]} - Fresh install: Hyprland Lua entrypoint already enabled." 2>&1 | tee -a "$log"
    return 0
  fi

  if [ -f "$hypr_dir/hyprland.lua.disable" ]; then
    mv -f "$hypr_dir/hyprland.lua.disable" "$hypr_dir/hyprland.lua"
    echo "${OK:-[OK]} - Fresh install: enabled default Hyprland Lua config (hyprland.lua)." 2>&1 | tee -a "$log"
    return 0
  fi

  if [ -f "$src_entry" ]; then
    cp -f "$src_entry" "$hypr_dir/hyprland.lua"
    echo "${OK:-[OK]} - Fresh install: installed default Hyprland Lua entrypoint from repo template." 2>&1 | tee -a "$log"
    return 0
  fi

  echo "${WARN:-[WARN]} - Fresh install: no hyprland.lua template found; left Hyprlang entrypoint as-is." 2>&1 | tee -a "$log"
  return 1
}

# Run scripts/migrate-hypr-to-lua.sh after upgrade restores when approved.
migrate_hypr_to_lua_if_needed() {
  local log="${1:-/dev/null}"
  local migrate_flag="${2:-${MIGRATE_HYPR_TO_LUA:-0}}"
  local base="${DOTFILES_DIR:-.}"
  local migrate_script="$base/scripts/migrate-hypr-to-lua.sh"
  local hypr_dir
  hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"

  if [ "$migrate_flag" != "1" ]; then
    echo "${NOTE:-[NOTE]} - LUA migration skipped by user choice." 2>&1 | tee -a "$log"
    return 0
  fi

  if [ ! -x "$migrate_script" ] && [ -f "$migrate_script" ]; then
    chmod +x "$migrate_script" 2>/dev/null || true
  fi

  if [ ! -f "$migrate_script" ]; then
    echo "${ERROR:-[ERROR]} - Migration script not found: $migrate_script" 2>&1 | tee -a "$log"
    return 1
  fi

  echo "${INFO:-[INFO]} - Migrating Hyprlang configuration to LUA via migrate-hypr-to-lua.sh..." 2>&1 | tee -a "$log"
  if "$migrate_script" --yes 2>&1 | tee -a "$log"; then
    echo "${OK:-[OK]} - Hyprland configuration migrated to LUA." 2>&1 | tee -a "$log"
    return 0
  fi

  echo "${ERROR:-[ERROR]} - LUA migration failed. Hyprlang config may still be active." 2>&1 | tee -a "$log"
  if [ -f "$hypr_dir/hyprland.lua.disable" ] && [ ! -f "$hypr_dir/hyprland.lua" ]; then
    echo "${NOTE:-[NOTE]} - Lua entrypoint remains disabled at $hypr_dir/hyprland.lua.disable" 2>&1 | tee -a "$log"
  fi
  return 1
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

      # UserConfigs are protected: only add missing templates
      if [ "$rel_dir" = "UserConfigs" ]; then
        if [ ! -f "$dst_file" ]; then
          mkdir -p "$(dirname "$dst_file")"
          if cp -f "$src_file" "$dst_file" 2>&1 | tee -a "$log"; then
            copied=1
            echo "${NOTE:-[NOTE]} - Added missing user config template: ${YELLOW:-}$rel_path${RESET:-}" 2>&1 | tee -a "$log"
          else
            echo "${ERROR:-[ERROR]} - Failed to add missing user config template: ${YELLOW:-}$rel_path${RESET:-}" 2>&1 | tee -a "$log"
          fi
        fi
      else
        # System directories (configs, lua): always sync/overwrite from repo
        mkdir -p "$(dirname "$dst_file")"
        if cp -f "$src_file" "$dst_file" 2>&1 | tee -a "$log"; then
          copied=1
          echo "${NOTE:-[NOTE]} - Synced system file: ${YELLOW:-}$rel_path${RESET:-}" 2>&1 | tee -a "$log"
        else
          echo "${ERROR:-[ERROR]} - Failed to sync system file: ${YELLOW:-}$rel_path${RESET:-}" 2>&1 | tee -a "$log"
        fi
      fi
    done < <(find "$src_dir" -maxdepth 1 -type f -name '*.lua' -print0)
  done

  # Sync root-level lua metadata and config files if present
  for root_lua in "$src_root"/*.lua; do
    [ -f "$root_lua" ] || continue
    local root_lua_name
    root_lua_name="$(basename "$root_lua")"
    if [ "$root_lua_name" != "hyprland.lua.disable" ]; then
      cp -f "$root_lua" "$dst_root/$root_lua_name" 2>&1 | tee -a "$log" || true
    fi
  done

  # Ensure canonical system window rules delegate to lua/window_rules.lua (all 93 rules)
  local sys_win_rules="$dst_root/configs/system_window_rules.lua"
  local src_win_rules="$src_root/configs/system_window_rules.lua"
  if [ -f "$src_win_rules" ]; then
    if [ ! -f "$sys_win_rules" ] || grep -q "No active window rules were found" "$sys_win_rules" 2>/dev/null || ! grep -q "window_rules\.lua" "$sys_win_rules" 2>/dev/null; then
      cp -f "$src_win_rules" "$sys_win_rules" 2>&1 | tee -a "$log" || true
      echo "${OK:-[OK]} - Ensured canonical system window rules: ${YELLOW:-}configs/system_window_rules.lua${RESET:-}" 2>&1 | tee -a "$log"
    fi
  fi

  # Patch existing user and system lua configs to fix startup readiness race condition
  for f in "$dst_root/UserConfigs"/*.lua "$dst_root/configs"/*.lua "$dst_root/lua"/*.lua; do
    [ -f "$f" ] || continue
    if grep -q 'break 2;' "$f" 2>/dev/null; then
      sed -i 's/break 2;/break;/g' "$f"
    fi
  done

  if [ "$copied" -eq 1 ]; then
    echo "${OK:-[OK]} - Lua files sync completed." 2>&1 | tee -a "$log"
  else
    echo "${INFO:-[INFO]} - Lua files check: up to date." 2>&1 | tee -a "$log"
  fi
}

# Restore Animations and Monitor Profiles plus key hypr files from backup
restore_hypr_assets() {
  local log="$1"
  local express_mode="$2"
  local base="${DOTFILES_DIR:-.}"

  local HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  local BACKUP_DIR
  BACKUP_DIR=$(get_backup_dirname)
  local BACKUP_HYPR_PATH="$HYPR_DIR-backup-$BACKUP_DIR"

  if [ -d "$BACKUP_HYPR_PATH" ]; then
    local backup_mode="conf"
    local backup_lua_entry="$BACKUP_HYPR_PATH/hyprland.lua"
    local backup_lua_disabled="$BACKUP_HYPR_PATH/hyprland.lua.disable"
    if [ -f "$backup_lua_entry" ]; then
      backup_mode="lua"
    elif [ -f "$backup_lua_disabled" ]; then
      # Explicit conf marker used by migrate-hypr-to-lua.sh while Lua is disabled.
      backup_mode="conf"
    fi

    # Preserve Lua entrypoint only when the backup was already using Lua mode.
    # Do not auto-enable or disable Lua on fresh install (handled by enable_fresh_install_lua_config).
    local LUA_ENTRY_TEMPLATE="$base/config/hypr/hyprland.lua"
    if [ ! -f "$LUA_ENTRY_TEMPLATE" ] && [ -f "$base/config/hypr/hyprland.lua.disable" ]; then
      LUA_ENTRY_TEMPLATE="$base/config/hypr/hyprland.lua.disable"
    fi
    if [ "${RUN_MODE:-}" != "install" ]; then
      if [ "$backup_mode" = "lua" ]; then
        if [ -f "$LUA_ENTRY_TEMPLATE" ]; then
          cp -f "$LUA_ENTRY_TEMPLATE" "$HYPR_DIR/hyprland.lua" 2>&1 | tee -a "$log"
          echo "${OK:-[OK]} - Restored file: ${MAGENTA:-}hyprland.lua${RESET:-} (lua mode preserved from repo template)" 2>&1 | tee -a "$log"
        elif [ -f "$BACKUP_HYPR_PATH/hyprland.lua" ]; then
          cp -f "$BACKUP_HYPR_PATH/hyprland.lua" "$HYPR_DIR/hyprland.lua" 2>&1 | tee -a "$log"
          echo "${OK:-[OK]} - Restored file: ${MAGENTA:-}hyprland.lua${RESET:-} (lua mode preserved from backup)" 2>&1 | tee -a "$log"
        fi
      else
        rm -f "$HYPR_DIR/hyprland.lua" 2>/dev/null || true
        echo "${NOTE:-[NOTE]} - Conf mode detected; skipping Lua entrypoint restore." 2>&1 | tee -a "$log"
      fi
    fi

    if [ "$express_mode" -eq 1 ]; then
      echo "${NOTE:-[NOTE]} Express mode: preserving existing wallpaper effects from backup and skipping animations/monitor profile restores." 2>&1 | tee -a "$log"
      local BACKUP_WALLPAPER_DIR="$BACKUP_HYPR_PATH/wallpaper_effects"
      if [ -d "$BACKUP_WALLPAPER_DIR" ]; then
        rm -rf "$HYPR_DIR/wallpaper_effects"
        cp -r "$BACKUP_WALLPAPER_DIR" "$HYPR_DIR/" 2>&1 | tee -a "$log"
        echo "${OK:-[OK]} - Restored directory: ${MAGENTA:-}wallpaper_effects${RESET:-}" 2>&1 | tee -a "$log"
      fi
      if [ -f "$BACKUP_HYPR_PATH/.initial_startup_done" ]; then
        cp -f "$BACKUP_HYPR_PATH/.initial_startup_done" "$HYPR_DIR/.initial_startup_done" 2>&1 | tee -a "$log"
        echo "${OK:-[OK]} - Preserved initial startup marker to avoid first-boot resets." 2>&1 | tee -a "$log"
      fi
    else
      echo -e "\n${NOTE:-[NOTE]} Restoring ${SKY_BLUE:-}Animations & Monitor Profiles${RESET:-} into ${YELLOW:-}$HYPR_DIR${RESET:-}..."

      # Fresh installs should apply repo defaults; do not restore a previous wallpaper.
      # RUN_MODE is set by copy.sh (install|upgrade|express) and is visible here.
      # Note: animations is a system directory and remains managed by dotfiles (not restored from backup).
      local DIR_B=("Monitor_Profiles")
      if [ "${RUN_MODE:-}" != "install" ]; then
        DIR_B+=("wallpaper_effects")
      else
        echo "${NOTE:-[NOTE]} Fresh install: skipping restore of wallpaper_effects so default wallpaper applies." 2>&1 | tee -a "$log"
      fi

      for DIR_RESTORE in "${DIR_B[@]}"; do
        local BACKUP_SUBDIR="$BACKUP_HYPR_PATH/$DIR_RESTORE"
        if [ -d "$BACKUP_SUBDIR" ]; then
          cp -r "$BACKUP_SUBDIR" "$HYPR_DIR/" 2>&1 | tee -a "$log"
          echo "${OK:-[OK]} - Restored directory: ${MAGENTA:-}$DIR_RESTORE${RESET:-}" 2>&1 | tee -a "$log"
        fi
      done
    fi

    # Restore custom Rofi themes and configurations from backup
    local BACKUP_ROFI_DIR="$BACKUP_HYPR_PATH/rofi"
    if [ ! -d "$BACKUP_ROFI_DIR" ] && [ -d "${HYPR_DIR}-${BACKUP_DIR}/rofi" ]; then
      BACKUP_ROFI_DIR="${HYPR_DIR}-${BACKUP_DIR}/rofi"
    fi

    if [ -d "$BACKUP_ROFI_DIR" ]; then
      # 1. Restore custom themes in rofi/themes/
      if [ -d "$BACKUP_ROFI_DIR/themes" ]; then
        mkdir -p "$HYPR_DIR/rofi/themes"
        for theme_file in "$BACKUP_ROFI_DIR/themes"/*; do
          [ -e "$theme_file" ] || continue
          local theme_name
          theme_name="$(basename "$theme_file")"
          if [ ! -e "$HYPR_DIR/rofi/themes/$theme_name" ]; then
            cp -r "$theme_file" "$HYPR_DIR/rofi/themes/$theme_name" 2>&1 | tee -a "$log" || true
            echo "${OK:-[OK]} - Restored custom rofi theme: ${MAGENTA:-}$theme_name${RESET:-}" 2>&1 | tee -a "$log"
          fi
        done
      fi

      # 2. Restore any custom/extra files in rofi/ root
      for rofi_file in "$BACKUP_ROFI_DIR"/*; do
        [ -e "$rofi_file" ] || continue
        [ -d "$rofi_file" ] && continue
        local rname
        rname="$(basename "$rofi_file")"
        if [ ! -e "$HYPR_DIR/rofi/$rname" ]; then
          cp -r "$rofi_file" "$HYPR_DIR/rofi/$rname" 2>&1 | tee -a "$log" || true
          echo "${OK:-[OK]} - Restored custom rofi file: ${MAGENTA:-}$rname${RESET:-}" 2>&1 | tee -a "$log"
        fi
      done
    fi

    # Keep monitor/workspace state across upgrades, including express mode.
    if [ "${RUN_MODE:-}" != "install" ]; then
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
  local BACKUP_DIR_PATH="$DIRPATH-backup-$BACKUP_DIR/UserConfigs"

  if [ -z "$BACKUP_DIR" ]; then
    echo "${ERROR:-[ERROR]} - Backup directory name is empty. Exiting." 2>&1 | tee -a "$log"
    exit 1
  fi

  if [ "${RUN_MODE:-}" = "install" ]; then
    if [ -d "$BACKUP_DIR_PATH" ]; then
      echo "${NOTE:-[NOTE]} Preserving existing UserConfigs directory during install." 2>&1 | tee -a "$log"
      rsync -a "$BACKUP_DIR_PATH/" "$DIRPATH/UserConfigs/" 2>&1 | tee -a "$log"
      echo "${OK:-[OK]} - UserConfigs directory preserved." 2>&1 | tee -a "$log"
    elif [ -d "${DIRPATH}-${BACKUP_DIR}/UserConfigs" ]; then
      echo "${NOTE:-[NOTE]} Preserving existing UserConfigs directory during install." 2>&1 | tee -a "$log"
      rsync -a "${DIRPATH}-${BACKUP_DIR}/UserConfigs/" "$DIRPATH/UserConfigs/" 2>&1 | tee -a "$log"
      echo "${OK:-[OK]} - UserConfigs directory preserved." 2>&1 | tee -a "$log"
    fi
    return
  fi

  if [ -d "$BACKUP_DIR_PATH" ]; then
    echo -e "${NOTE:-[NOTE]} Restoring previous ${MAGENTA:-}User-Configs${RESET:-}... " 2>&1 | tee -a "$log"
    if [ "$express_mode" -eq 1 ]; then
      echo "${NOTE:-[NOTE]} Express mode: restoring UserConfigs directory automatically." 2>&1 | tee -a "$log"
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
  fi
}

restore_user_scripts() {
  local log="$1"
  local express_mode="$2"

  local DIRSHPATH="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  local BACKUP_DIR
  BACKUP_DIR=$(get_backup_dirname)
  local BACKUP_DIR_PATH_S="$DIRSHPATH-backup-$BACKUP_DIR/UserScripts"

  if [ -z "$BACKUP_DIR" ]; then
    return 0
  fi

  # Check alternate backup path used by prepare_fresh_install_hypr
  if [ ! -d "$BACKUP_DIR_PATH_S" ] && [ -d "${DIRSHPATH}-${BACKUP_DIR}/UserScripts" ]; then
    BACKUP_DIR_PATH_S="${DIRSHPATH}-${BACKUP_DIR}/UserScripts"
  fi

  if [ ! -d "$BACKUP_DIR_PATH_S" ]; then
    return 0
  fi

  if [ "${RUN_MODE:-}" = "install" ]; then
    echo "${NOTE:-[NOTE]} Preserving existing UserScripts directory during install." 2>&1 | tee -a "$log"
    rsync -a "$BACKUP_DIR_PATH_S/" "$DIRSHPATH/UserScripts/" 2>&1 | tee -a "$log"
    echo "${OK:-[OK]} - UserScripts directory preserved." 2>&1 | tee -a "$log"
    chmod +x "$DIRSHPATH/UserScripts/"* 2>/dev/null || true
    return 0
  fi

  echo -e "${NOTE:-[NOTE]} Restoring previous ${MAGENTA:-}User-Scripts${RESET:-}... " 2>&1 | tee -a "$log"

  if [ "$express_mode" -eq 1 ]; then
    echo "${NOTE:-[NOTE]} Restoring UserScripts directory automatically." 2>&1 | tee -a "$log"
    rsync -a "$BACKUP_DIR_PATH_S/" "$DIRSHPATH/UserScripts/" 2>&1 | tee -a "$log"
    echo "${OK:-[OK]} - UserScripts directory restored." 2>&1 | tee -a "$log"
  else
    read -r -p "${CAT:-[ACTION]} Do you want to restore your previous UserScripts directory? (Y/n): " restore_userscripts_dir
    if [[ "$restore_userscripts_dir" != [Nn]* ]]; then
      echo "${NOTE:-[NOTE]} Restoring UserScripts directory..." 2>&1 | tee -a "$log"
      rsync -a "$BACKUP_DIR_PATH_S/" "$DIRSHPATH/UserScripts/" 2>&1 | tee -a "$log"
      echo "${OK:-[OK]} - UserScripts directory restored." 2>&1 | tee -a "$log"
    else
      echo "${NOTE:-[NOTE]} - Skipped restoring UserScripts." 2>&1 | tee -a "$log"
    fi
  fi

  chmod +x "$DIRSHPATH/UserScripts/"* 2>/dev/null || true
}

restore_terminal_configs() {
  local log="$1"
  local express_mode="$2"

  local GHOSTTY_DIR="${XDG_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}/ghostty"
  local BACKUP_DIR
  BACKUP_DIR=$(get_backup_dirname)
  local GHOSTTY_BACKUP="$GHOSTTY_DIR-backup-$BACKUP_DIR"

  if [ -d "$GHOSTTY_BACKUP" ]; then
    if [ "$express_mode" -eq 1 ]; then
      echo "${NOTE:-[NOTE]} Express mode: automatically preserving Ghostty config from backup." 2>&1 | tee -a "$log"
      rm -rf "$GHOSTTY_DIR"
      cp -a "$GHOSTTY_BACKUP" "$GHOSTTY_DIR" 2>&1 | tee -a "$log"
      return
    fi

    echo -e "${NOTE:-[NOTE]} Restore previous ${MAGENTA:-}Ghostty${RESET:-} config?" 2>&1 | tee -a "$log"
    read -r -p "${CAT:-[ACTION]} Do you want to restore Ghostty config from backup? (y/N): " restore_ghostty
    if [[ "$restore_ghostty" == [Yy]* ]]; then
      rm -rf "$GHOSTTY_DIR"
      cp -a "$GHOSTTY_BACKUP" "$GHOSTTY_DIR" 2>&1 | tee -a "$log"
      echo "${OK:-[OK]} - Ghostty config restored." 2>&1 | tee -a "$log"
    else
      echo "${NOTE:-[NOTE]} - Skipped restoring Ghostty config." 2>&1 | tee -a "$log"
    fi
  fi
}
restore_hypr_files() {
  local log="$1"
  local express_mode="$2"

  local DIRPATH="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  local BACKUP_DIR
  BACKUP_DIR=$(get_backup_dirname)
  local BACKUP_DIR_PATH_F="$DIRPATH-backup-$BACKUP_DIR"
  local FILES_2_RESTORE=("hyprlock.conf" "hypridle.conf")

  if [ -d "$BACKUP_DIR_PATH_F" ]; then
    if [ "$express_mode" -eq 1 ]; then
      echo "${NOTE:-[NOTE]} Express mode: automatically preserving hyprlock.conf and hypridle.conf from backup." 2>&1 | tee -a "$log"
      for FILE_RESTORE in "${FILES_2_RESTORE[@]}"; do
        local BACKUP_FILE="$BACKUP_DIR_PATH_F/$FILE_RESTORE"
        if [ -f "$BACKUP_FILE" ]; then
          cp -f "$BACKUP_FILE" "$DIRPATH/$FILE_RESTORE" 2>&1 | tee -a "$log"
        fi
      done
      return
    fi

    local has_any=0
    for FILE_RESTORE in "${FILES_2_RESTORE[@]}"; do
      [ -f "$BACKUP_DIR_PATH_F/$FILE_RESTORE" ] && has_any=1
    done
    if [ "$has_any" -eq 1 ]; then
      echo -e "\n${NOTE:-[NOTE]} Preserving customized hyprlock.conf / hypridle.conf from backup..." 2>&1 | tee -a "$log"
      for FILE_RESTORE in "${FILES_2_RESTORE[@]}"; do
        local BACKUP_FILE="$BACKUP_DIR_PATH_F/$FILE_RESTORE"
        if [ -f "$BACKUP_FILE" ]; then
          cp -f "$BACKUP_FILE" "$DIRPATH/$FILE_RESTORE" 2>&1 | tee -a "$log"
          echo "${OK:-[OK]} - Preserved previous $FILE_RESTORE from backup." 2>&1 | tee -a "$log"
        fi
      done
    fi
  fi
}
