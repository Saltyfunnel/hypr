#!/bin/bash
# setwall.sh - Proper pywal16 workflow
set -euo pipefail

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

# ----------------------------
# Start swww-daemon if needed
# ----------------------------
if ! pgrep -x "swww-daemon" >/dev/null; then
    swww-daemon &
    sleep 1
fi

# ----------------------------
# Pick wallpaper
# ----------------------------
if [[ -z "${1-}" ]]; then
    WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" \) | shuf -n 1)
else
    WALLPAPER="$1"
fi

[[ -z "$WALLPAPER" ]] && { echo "No wallpapers found in $WALLPAPER_DIR"; exit 1; }

# ----------------------------
# Set wallpaper
# ----------------------------
swww img "$WALLPAPER" --transition-type any --transition-step 90 --transition-fps 60

# ----------------------------
# Generate pywal theme (auto-processes ALL templates)
# ----------------------------
wal -n -q -i "$WALLPAPER"

# Small delay to ensure cache is written
sleep 0.3

# ----------------------------
# Reload services to pick up new colors
# ----------------------------
# Waybar
pkill -USR2 waybar 2>/dev/null || waybar &

# Mako (needs restart to reload config)
pkill mako 2>/dev/null
mako &

# Kitty (if running, send signal to reload)
killall -SIGUSR1 kitty 2>/dev/null || true

# ----------------------------
# Done!
# ----------------------------
notify-send "Theme Updated" "Wallpaper and colors applied!" -u low

echo "✅ Theme updated successfully!"
