#!/bin/bash
# ~/.config/scripts/setwall.sh
# DO NOT TOUCH - WORKING LOGIC (With Mako Notification Fix)

WALL="$1"

# 1. Standard Pywal
wal -i "$WALL"

# 2. Stable SWWW
swww img "$WALL" --transition-type simple

# 3. The Sync Gap (Wait for files to write)
sleep 0.5

# 4. Component Reset
killall waybar 2>/dev/null
waybar &

# 5. Mako Restart & Notification
killall mako 2>/dev/null
sleep 0.3
mako & 
disown # This keeps mako running after the script exits

# 6. Send the test notification
# This will now trigger once mako is back up
notify-send -i "$WALL" "Theme Updated" "Colors synced to $(basename "$WALL")"

# 7. Hyprland Borders
hyprctl reload
