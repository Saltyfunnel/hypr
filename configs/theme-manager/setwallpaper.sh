#!/bin/bash
# ~/.config/theme-manager/setwallpaper.sh
# Select a wallpaper with Yazi and set it via swww

source ~/.config/theme-manager/config.sh

TERMINAL="kitty"
FILE_MANAGER="yazi"

TMP_FILE=$(mktemp)

# Launch Yazi in your wallpaper directory
$TERMINAL -e bash -c "$FILE_MANAGER --chooser-file $TMP_FILE $WALLPAPER_DIR"

SELECTED_FILE=$(cat "$TMP_FILE")
rm "$TMP_FILE"

if [ -f "$SELECTED_FILE" ]; then
    swww img "$SELECTED_FILE" --transition-type "$SWWW_TRANSITION" --transition-duration "$SWWW_DURATION"

    # Save chosen wallpaper path for other scripts
    echo "$SELECTED_FILE" > "$PYWAL_CACHE/current_wallpaper"

    echo "Wallpaper set to $SELECTED_FILE"
else
    echo "No valid file selected."
fi
