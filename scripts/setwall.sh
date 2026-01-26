#!/bin/bash
# High-Performance Wallpaper Setter

if [ -z "$1" ]; then
    exit 1
fi

WALL="$1"

# 1. Update Colors
wal -i "$WALL" -q

# 2. Update Wallpaper (AMD Fixes)
swww img "$WALL" --transition-type grow --transition-fps 165 --transition-duration 1.5

# 3. RELIABLE WAYBAR RESTART
# Instead of USR1, we kill and restart to ensure the new CSS is loaded properly
killall waybar
waybar &

# 4. Refresh Mako
makoctl reload

# 5. Refresh Hyprland
hyprctl reload
