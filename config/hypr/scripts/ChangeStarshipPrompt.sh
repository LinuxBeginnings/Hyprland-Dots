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
ROFI_THEME="$CONFIG_HOME/hypr/rofi/config-starship.rasi"
RESTORE_LABEL="Restore original prompt"
# Same indicator the other selection menus use. Never part of a prompt name.
MARKER="👉"

if ! command -v starship >/dev/null 2>&1; then
  echo "starship is not installed"
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

# What is loaded now: starship.toml is a symlink to the chosen prompt, so the
# target is the only reliable statement of it. A plain file means the user
# edited their own prompt, and nothing in the list is current.
current_prompt=""
if [[ -L "$STARSHIP_CONFIG" ]]; then
  current_target="$(readlink -f "$STARSHIP_CONFIG" 2>/dev/null || true)"
  for prompt in "${available_prompts[@]}"; do
    if [[ "$current_target" == "$STARSHIP_DIR/$prompt" || "$current_target" == "$HYPR_STARSHIP_DIR/$prompt" ]]; then
      current_prompt="$prompt"
      break
    fi
  done
fi

rofi_options=("${available_prompts[@]}")
if [[ -f "$BACKUP_FILE" ]]; then
  rofi_options+=("$RESTORE_LABEL")
fi

# Mark the loaded prompt and pre-select its row. The restore entry is never a
# current state, so it is left unmarked.
default_row=0
if [[ -n "$current_prompt" ]]; then
  for i in "${!rofi_options[@]}"; do
    if [[ "${rofi_options[$i]}" == "$current_prompt" ]]; then
      rofi_options[i]="$MARKER ${rofi_options[$i]}"
      default_row=$i
      break
    fi
  done
fi

"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true

selection="$(printf '%s\n' "${rofi_options[@]}" | rofi -dmenu -i -p "Select Starship Prompt" -mesg "Current: ${current_prompt:-custom}" -theme "$ROFI_THEME" -selected-row "$default_row")"

if [[ -z "$selection" ]]; then
  exit 0
fi

# Strip the marker before the choice is used as a file name.
selection="${selection#"$MARKER "}"

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
