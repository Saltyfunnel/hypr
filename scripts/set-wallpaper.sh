#!/bin/bash
# Set wallpaper via Hyprpaper and Pywal

WALLPAPER="$HOME/Pictures/wallpaper.jpg"

# Set wallpaper with hyprpaper
if command -v hyprpaper &>/dev/null; then
    hyprpaper --random "$WALLPAPER"
fi

# Apply pywal colors
if command -v wal &>/dev/null; then
    wal -i "$WALLPAPER" -n
fi