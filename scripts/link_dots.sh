#!/usr/bin/env bash

# link_dots.sh
# Safely backups existing files/dirs in ~/.config and symlinks them to ~/code/temp/Hyprland-dots/config/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_CONFIG_DIR="$(cd "$SCRIPT_DIR/../config" && pwd)"
TARGET_DIR="$HOME/.config"
TIMESTAMP=$(date +%Y%m%d%H%M%S)

echo "Starting synchronization of config files..."
echo "Source: $DOTFILES_CONFIG_DIR"
echo "Target: $TARGET_DIR"
echo

# Ensure target directory exists
mkdir -p "$TARGET_DIR"

# Loop through all files and directories in the dotfiles config folder (including hidden ones)
shopt -s dotglob
for item_path in "$DOTFILES_CONFIG_DIR"/*; do
    [ -e "$item_path" ] || continue
    item_name=$(basename "$item_path")
    
    target_path="$TARGET_DIR/$item_name"
    
    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
        # If it's already a symlink pointing to the correct source, skip it
        if [ -L "$target_path" ] && [ "$(readlink -f "$target_path")" = "$(readlink -f "$item_path")" ]; then
            echo "✓ $item_name is already correctly symlinked."
            continue
        fi
        
        # If it is a real file or directory (not a symlink), back it up
        if [ ! -L "$target_path" ]; then
            backup_path="${target_path}.bak.${TIMESTAMP}"
            echo "⚠️  Moving existing target $target_path to $backup_path"
            mv "$target_path" "$backup_path"
        else
            # If it is a symlink pointing elsewhere, remove the old symlink
            echo "Replacing existing symlink for $item_name"
            rm "$target_path"
        fi
    fi
    
    # Create the symlink
    echo "Creating symlink for $item_name"
    ln -sf "$item_path" "$target_path"
done
shopt -u dotglob

echo
echo "✓ Sync complete! All dotfiles in ~/.config are now symlinked to $DOTFILES_CONFIG_DIR"
echo "You can now edit files in ~/.config as normal, and commit/push changes from ~/code/temp/Hyprland-dots."
