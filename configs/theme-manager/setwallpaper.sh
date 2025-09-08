#!/bin/bash
# ~/.config/theme-manager/setwallpaper.sh
# Launch Kitty with Yazi to select a wallpaper, then set it using swww

TERMINAL="kitty"
FILE_MANAGER="yazi"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

# Create a temporary file to capture Yazi's selected file
TMP_FILE=$(mktemp)

# Launch Yazi starting in the wallpaper directory
$TERMINAL -e bash -c "$FILE_MANAGER --chooser-file $TMP_FILE $WALLPAPER_DIR"

# Read the file Yazi selected
SELECTED_FILE=$(cat "$TMP_FILE")

# Clean up
rm "$TMP_FILE"

# Check if a valid file was selected
if [ -f "$SELECTED_FILE" ]; then
    swww img "$SELECTED_FILE" --transition-type fade --transition-duration 2
else
    echo "No valid file selected or cancelled."
fi
