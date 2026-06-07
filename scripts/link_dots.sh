#!/usr/bin/env bash

# link_dots.sh
# Safely backups existing files/dirs in ~/.config and ~/.zshrc and symlinks them to ~/code/temp/Hyprland-dots/config/

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
    
    # Skip standard metadata / Git / ignore files that shouldn't be symlinked to ~/.config
    if [[ "$item_name" == "." || "$item_name" == ".." || "$item_name" == ".git" || "$item_name" == ".gitignore" || "$item_name" == "README.md" || "$item_name" == "AGENTS.md" || "$item_name" == "tool_state" ]]; then
        continue
    fi
    
    # If the item is 'zshrc', link it to ~/.zshrc instead of ~/.config/zshrc
    if [ "$item_name" = "zshrc" ]; then
        target_path="$HOME/.zshrc"
    else
        target_path="$TARGET_DIR/$item_name"
    fi
    
    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
        # If it's already a symlink pointing to the correct source, skip it
        if [ -L "$target_path" ] && [ "$(readlink -f "$target_path")" = "$(readlink -f "$item_path")" ]; then
            echo "✓ $item_name is already correctly symlinked to $target_path."
            continue
        fi
        
        # If it is a real file or directory (not a symlink), back it up
        if [ ! -L "$target_path" ]; then
            backup_path="${target_path}.bak.${TIMESTAMP}"
            echo "⚠️  Moving existing target $target_path to $backup_path"
            mv "$target_path" "$backup_path"
        else
            # If it is a symlink pointing elsewhere, remove the old symlink
            echo "Replacing existing symlink for $item_name at $target_path"
            rm "$target_path"
        fi
    fi
    
    # Create the symlink
    echo "Creating symlink for $item_name -> $target_path"
    ln -sf "$item_path" "$target_path"
done
shopt -u dotglob

# Cleanup old redundant/mistaken symlinks in ~/.config
for old_symlink in "zshrc" "dns.sh" "updatehaha.sh" "AGENTS.md" "tool_state" "README.md" ".gitignore"; do
    if [ -L "$TARGET_DIR/$old_symlink" ]; then
        echo "🧹 Cleaning up legacy redundant symlink at $TARGET_DIR/$old_symlink"
        rm "$TARGET_DIR/$old_symlink"
    fi
done

echo
echo "✓ Sync complete! All dotfiles are now symlinked."
echo "You can now edit files as normal, and commit/push changes from $SCRIPT_DIR/.."
