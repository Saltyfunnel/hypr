#!/bin/bash
# setwall.sh - Random wallpaper setter + Pywal + Waybar theming
set -euo pipefail

# ----------------------------
# Directories
# ----------------------------
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
WAYBAR_CSS="$HOME/.config/waybar/colors.css"
PYWAL_CACHE="$HOME/.cache/wal/colors.css"

# ----------------------------
# Start swww-daemon if needed
# ----------------------------
if ! pgrep -x "swww-daemon" >/dev/null; then
    echo "Starting swww-daemon..."
    swww-daemon &
    sleep 1
fi

# ----------------------------
# Pick a random wallpaper
# ----------------------------
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" \) | shuf -n 1)
if [[ -z "$WALLPAPER" ]]; then
    echo "No wallpapers found in $WALLPAPER_DIR"
    exit 1
fi

echo "Setting wallpaper: $WALLPAPER"
swww img "$WALLPAPER" --transition-type any --transition-step 90 --transition-fps 60

# ----------------------------
# Generate Pywal colors
# ----------------------------
wal -n -q -i "$WALLPAPER"

# ----------------------------
# Extract colors from Pywal
# ----------------------------
BG=$(grep color0 "$PYWAL_CACHE" | grep -o '#[0-9A-Fa-f]\{6\}' | head -n1)
FG=$(grep color7 "$PYWAL_CACHE" | grep -o '#[0-9A-Fa-f]\{6\}' | head -n1)
COLOR1=$(grep color1 "$PYWAL_CACHE" | grep -o '#[0-9A-Fa-f]\{6\}' | head -n1)
COLOR2=$(grep color2 "$PYWAL_CACHE" | grep -o '#[0-9A-Fa-f]\{6\}' | head -n1)
COLOR3=$(grep color3 "$PYWAL_CACHE" | grep -o '#[0-9A-Fa-f]\{6\}' | head -n1)
COLOR4=$(grep color4 "$PYWAL_CACHE" | grep -o '#[0-9A-Fa-f]\{6\}' | head -n1)

# ----------------------------
# Write Waybar-compatible CSS
# ----------------------------
mkdir -p "$(dirname "$WAYBAR_CSS")"

cat > "$WAYBAR_CSS" <<EOF
/* Auto-generated Waybar colors from Pywal */
.modules-left, .modules-center, .modules-right {
    background-color: $BG;
    color: $FG;
}

#workspaces button.active {
    background-color: $COLOR1;
    color: $BG;
}

#clock { color: $COLOR3; }
#cpu { color: $COLOR2; }
#memory { color: $COLOR4; }
#pulseaudio { color: $COLOR2; }
#pulseaudio.muted { color: $BG; }
EOF

echo "Waybar colors updated at $WAYBAR_CSS"

# ----------------------------
# Reload Waybar
# ----------------------------
if pgrep -x "waybar" >/dev/null; then
    echo "Reloading Waybar..."
    pkill -USR2 waybar
else
    echo "Waybar not running, starting it..."
    waybar &
fi

echo "Done! Wallpaper and Waybar theme updated."
