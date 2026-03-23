#!/bin/bash

CONFIG="$HOME/.config/rofi/launcher.rasi"
WALL_FILE="$HOME/.cache/wal/wal"
ROFI_WAL_COLORS="$HOME/.cache/wal/colors-rofi-dark.rasi"

# Check pywal
if [[ ! -f "$WALL_FILE" ]]; then
    notify-send "Rofi Error" "Run 'wal' first."
    exit 1
fi

WALL=$(cat "$WALL_FILE")

# Extract background color safely
BG=$(grep -m1 "background:" "$ROFI_WAL_COLORS" | awk '{print $2}' | tr -d ';#')

# Update wallpaper
sed -i "s|background-image:.*|background-image:            url(\"$WALL\", height);|" "$CONFIG"

# Update window transparency
sed -i "s|background-color:.*\/\* window-bg \*\/|background-color:            #DD${BG}; /* window-bg */|" "$CONFIG"

# Launch rofi
rofi -show drun -theme "$CONFIG"
