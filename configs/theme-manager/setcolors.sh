#!/bin/bash
# ~/.config/theme-manager/setcolors.sh

source ~/.config/theme-manager/config.sh

if [ ! -f "$PYWAL_CACHE/current_wallpaper" ]; then
    echo "No wallpaper selected yet!"
    exit 1
fi

WALLPAPER=$(cat "$PYWAL_CACHE/current_wallpaper")

# Generate Pywal colors
wal -i "$WALLPAPER" -n

# Reload Waybar
killall waybar
waybar &


echo "Colors applied based on $WALLPAPER"
