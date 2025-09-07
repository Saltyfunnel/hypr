#!/bin/bash
# ~/.config/theme-wallpaper/set-wallpaper.sh

SELECTED_WALLPAPER="$1"
if [ -z "$SELECTED_WALLPAPER" ]; then
    echo "Error: No wallpaper path provided." >&2
    exit 1
fi

# Set the wallpaper using swww.
swww img "$SELECTED_WALLPAPER"