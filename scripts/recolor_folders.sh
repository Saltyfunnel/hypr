#!/bin/bash
# 1. Give pywal a half-second to finish writing the JSON
sleep 0.5

# 2. Get the NEW color from the cache
NEW_COLOR=$(jq -r '.colors.color4' < "$HOME/.cache/wal/colors.json" | tr -d '[:space:]')

# 3. Target the icons. 
# We replace ANY hex code that isn't #ffffff (white) or #333333 (grey)
# This ensures it works even if the icons were already recolored once.
find "$HOME/.local/share/icons/Colloid-Dynamic-Dark" -name "*.svg" -exec sed -i "/#ffffff\|#333333/!s/#[a-fA-F0-9]\{6\}/$NEW_COLOR/gI" {} +

# 4. Nuclear Cache Clear (CRITICAL for Thunar)
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/Colloid-Dynamic-Dark"
rm -rf ~/.cache/thumbnails/*
killall tumblerd thunar 2>/dev/null || true

# 5. The "Magic Switch" to force GTK to redraw
gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'
sleep 0.2
gsettings set org.gnome.desktop.interface icon-theme 'Colloid-Dynamic-Dark'
