#!/bin/bash

ICON_DIR="$HOME/.local/share/icons/Colloid-Dynamic-Dark"
CACHE="$HOME/.cache/wal/colors.json"

# Get new colour
NEW_COLOR=$(jq -r '.colors.color4' < "$CACHE" | tr -d '[:space:]')

# Track previous colour to do a targeted swap instead of full scan
PREV_FILE="$HOME/.cache/wal/prev_icon_color"
PREV_COLOR=$(cat "$PREV_FILE" 2>/dev/null)

if [ -n "$PREV_COLOR" ] && [ "$PREV_COLOR" != "$NEW_COLOR" ]; then
    # Fast path: only touch files containing the old colour
    grep -rl "$PREV_COLOR" "$ICON_DIR" --include="*.svg" | \
        xargs sed -i "s/$PREV_COLOR/$NEW_COLOR/gI"
else
    # First run or same colour: full scan (slow, but rare)
    find "$ICON_DIR" -name "*.svg" -exec \
        sed -i "/#ffffff\|#333333/!s/#[a-fA-F0-9]\{6\}/$NEW_COLOR/gI" {} +
fi

# Save current colour for next run
echo "$NEW_COLOR" > "$PREV_FILE"

# Icon cache + GTK reload
gtk-update-icon-cache -f -t "$ICON_DIR" &
rm -rf ~/.cache/thumbnails/* &
wait

killall tumblerd thunar 2>/dev/null || true

gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'
sleep 0.2
gsettings set org.gnome.desktop.interface icon-theme 'Colloid-Dynamic-Dark'
