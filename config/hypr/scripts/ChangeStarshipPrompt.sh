#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Switch Starship prompt configs via Rofi.

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STARSHIP_DIR="$CONFIG_HOME/starship"
HYPR_STARSHIP_DIR="$CONFIG_HOME/hypr/starship"
STARSHIP_CONFIG="$CONFIG_HOME/starship.toml"
BACKUP_FILE="$STARSHIP_CONFIG.original"
ROFI_THEME="$CONFIG_HOME/rofi/config-starship.rasi"
RESTORE_LABEL="Retore orignal prompt"

is_starship_enabled() {
  if [[ -n "${STARSHIP_SHELL:-}" ]]; then
    return 0
  fi
  pgrep -x starship >/dev/null 2>&1
}

if ! is_starship_enabled; then
  echo "starship not enabled"
  exit 1
fi

if [[ ! -f "$ROFI_THEME" ]]; then
  echo "Rofi theme not found: $ROFI_THEME"
  exit 1
fi

if [[ ! -d "$STARSHIP_DIR" ]]; then
  echo "Starship config directory not found: $STARSHIP_DIR"
  exit 1
fi

mapfile -t available_prompts < <(find "$STARSHIP_DIR" -maxdepth 1 -type f -name "*.toml" -printf "%f\n" 2>/dev/null | sort -V)

if [[ ${#available_prompts[@]} -eq 0 ]]; then
  echo "No Starship prompt files found in $STARSHIP_DIR"
  exit 1
fi

rofi_options=("${available_prompts[@]}")
if [[ -f "$BACKUP_FILE" ]]; then
  rofi_options+=("$RESTORE_LABEL")
fi

selection="$(printf '%s\n' "${rofi_options[@]}" | rofi -dmenu -i -p "Select Starship Prompt" -mesg "Select Starship Prompt" -theme "$ROFI_THEME")"

if [[ -z "$selection" ]]; then
  exit 0
fi

if [[ "$selection" == "$RESTORE_LABEL" ]]; then
  if [[ -f "$BACKUP_FILE" ]]; then
    if [[ -L "$STARSHIP_CONFIG" ]]; then
      rm -f "$STARSHIP_CONFIG"
    fi
    cp -f "$BACKUP_FILE" "$STARSHIP_CONFIG"
  else
    echo "Backup not found: $BACKUP_FILE"
  fi
  exit 0
fi

selected_path="$STARSHIP_DIR/$selection"
if [[ ! -f "$selected_path" && -f "$HYPR_STARSHIP_DIR/$selection" ]]; then
  selected_path="$HYPR_STARSHIP_DIR/$selection"
fi

if [[ ! -f "$selected_path" ]]; then
  echo "Selected prompt not found: $selection"
  exit 1
fi

if [[ -f "$STARSHIP_CONFIG" && ! -L "$STARSHIP_CONFIG" ]]; then
  cp -f "$STARSHIP_CONFIG" "$BACKUP_FILE"
  rm -f "$STARSHIP_CONFIG"
fi

ln -sfn "$selected_path" "$STARSHIP_CONFIG"
