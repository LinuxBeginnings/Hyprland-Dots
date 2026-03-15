#!/usr/bin/env bash

# 1. Get the specific ID and the "ID_LIKE" family
source /etc/os-release
SPECIFIC_ID=$ID
FAMILY_ID=$ID_LIKE

# 2. Define your asset directory
ASSET_DIR="$HOME/.config/fastfetch/images"

# 3. Selection Logic
if [ -f "$ASSET_DIR/$SPECIFIC_ID.png" ]; then
  # Use exact match if available (e.g., soplos.png)
  SELECTED_LOGO="$ASSET_DIR/$SPECIFIC_ID.png"
elif [ -n "$FAMILY_ID" ] && [ -f "$ASSET_DIR/${FAMILY_ID%% *}.png" ]; then
  # Fallback to family (e.g., debian.png) - takes the first word of ID_LIKE
  SELECTED_LOGO="$ASSET_DIR/${FAMILY_ID%% *}.png"
else
  # Let fastfetch handle it natively if no custom image found
  fastfetch
  exit 0
fi

fastfetch --kitty "$SELECTED_LOGO"
