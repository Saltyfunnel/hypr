#!/bin/bash
# setwall.sh - Proper pywal16 workflow
set -euo pipefail

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
SCREENSHOT_SCRIPT="$HOME/.local/bin/screenshot_notify.sh"

# ----------------------------
# Create screenshot script if it doesn't exist
# ----------------------------
mkdir -p "$(dirname "$SCREENSHOT_SCRIPT")"
mkdir -p "$SCREENSHOT_DIR"

cat > "$SCREENSHOT_SCRIPT" <<'SCRIPT_END'
#!/bin/bash
DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/screenshot_$(date +%F_%T).png"

case "$1" in
    area)
        grim -g "$(slurp)" "$FILE" && notify-send "Screenshot" "Area saved to $FILE" -i "$FILE"
        ;;
    window)
        grim -g "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" "$FILE" && notify-send "Screenshot" "Window saved to $FILE" -i "$FILE"
        ;;
    screen)
        grim "$FILE" && notify-send "Screenshot" "Screen saved to $FILE" -i "$FILE"
        ;;
    *)
        grim "$FILE" && notify-send "Screenshot" "Screen saved to $FILE" -i "$FILE"
        ;;
esac
SCRIPT_END

chmod +x "$SCREENSHOT_SCRIPT"

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
