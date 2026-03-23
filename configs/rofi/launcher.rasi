#!/bin/bash

# Define paths
CONFIG="$HOME/.config/rofi/launcher.rasi"
WALL_FILE="$HOME/.cache/wal/wal"
ROFI_WAL_COLORS="$HOME/.cache/wal/colors-rofi-dark.rasi"

# Check if pywal files exist
if [[ ! -f "$WALL_FILE" ]]; then
    notify-send "Rofi Error" "No wallpaper found in cache. Run 'wal' first."
    exit 1
fi

# Current wallpaper path
WALL=$(cat "$WALL_FILE")

# Extract the background color from pywal-generated rofi file
# We grab the hex and strip the '#' and ';'
BG=$(grep "background:" "$ROFI_WAL_COLORS" | head -n 1 | awk '{print $2}' | tr -d ';#')

# 1. Update the wallpaper image path
sed -i "s|background-image:.*|background-image:            url(\"$WALL\", height);|" "$CONFIG"

# 2. Update the window background with transparency (DD = ~86% opacity)
sed -i "s|background-color:.*\/\* window-bg \*\/|background-color:            #DD${BG}; /* window-bg */|" "$CONFIG"

# Execute rofi
rofi -show drun -theme "$CONFIG"
