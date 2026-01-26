#!/bin/bash
# ----------------------------------------------------------------              
# AMD-Optimized Wallpaper Setter (Full Path & Daemon Fix)
# ----------------------------------------------------------------

if [ -z "$1" ]; then
    echo "Error: No wallpaper path provided."
    exit 1
fi

# Convert to absolute path so swww never misses it
WALLPAPER=$(readlink -f "$1")

# 1. Update Pywal Colors
wal -i "$WALLPAPER" -q

# 2. Check if swww-daemon is running, if not, start it
if ! pgrep -x "swww-daemon" > /dev/null; then
    swww-daemon --format xrgb &
    sleep 1 # Give it a second to initialize
fi

# 3. Apply Wallpaper with AMD-safe grow transition
swww img "$WALLPAPER" \
    --transition-type grow \
    --transition-fps 165 \
    --transition-duration 1.5 \
    --transition-pos 0.5,0.5

# 4. Refresh UI Components
killall waybar && waybar &
makoctl reload
hyprctl reload

echo "Wallpaper applied: $WALLPAPER"
