#!/bin/bash

# Log for debugging
LOG_FILE="/tmp/themes_wallpaper_debug.log"
echo "Starting wallpaper theming script..." > "$LOG_FILE"

# Directories
WALL_DIR="$HOME/.config/assets/wallpapers"

# Check that the wallpaper directory exists
if [ ! -d "$WALL_DIR" ]; then
    echo "Error: Wallpaper directory not found at $WALL_DIR" >> "$LOG_FILE"
    exit 1
fi

# Launch Waypaper to pick a wallpaper
SELECTED_WALL=$(waypaper --folder "$WALL_DIR" --backend swww --fill fit --no-post-command)

if [ -z "$SELECTED_WALL" ]; then
    echo "No wallpaper selected." >> "$LOG_FILE"
    exit 1
fi

echo "Selected wallpaper: $SELECTED_WALL" >> "$LOG_FILE"

# Apply wallpaper using swww
if ! pgrep -x "swww-daemon" > /dev/null; then
    echo "Starting swww-daemon..." >> "$LOG_FILE"
    swww-daemon &
    sleep 1
fi

swww img "$SELECTED_WALL" --transition-type grow --transition-duration 1 --transition-fps 60
echo "Wallpaper applied with swww." >> "$LOG_FILE"

# Generate pywal colors
wal -i "$SELECTED_WALL" -n
echo "Pywal colors generated." >> "$LOG_FILE"

# Restart Waybar to apply colors
pkill waybar && waybar &
echo "Waybar restarted." >> "$LOG_FILE"

echo "Done!" >> "$LOG_FILE"
