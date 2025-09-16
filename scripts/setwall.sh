#!/bin/bash
# setwall.sh - Random wallpaper setter + Pywal + Waybar + Thunar theming
set -euo pipefail

# ----------------------------
# Directories
# ----------------------------
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
WAYBAR_CSS="$HOME/.config/waybar/colors.css"
PYWAL_CACHE="$HOME/.cache/wal/colors.sh"

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

# Load Pywal's color variables
source "$PYWAL_CACHE"

# ----------------------------
# Extract colors for Waybar
# ----------------------------
BG="$color0"
FG="$color7"
COLOR1="$color1"
COLOR2="$color2"
COLOR3="$color3"
COLOR4="$color4"

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
# Update Thunar folder icons
# ----------------------------
if command -v papirus-folders &>/dev/null; then
    # Strip the '#' from the color for papirus-folders
    FOLDER_COLOR="${COLOR1#'#'}"

    echo "Updating Papirus folder color to: $FOLDER_COLOR"
    papirus-folders -C "$FOLDER_COLOR" --theme Papirus-Dark

    # Refresh GTK icon cache (optional, prevents stale icons)
    if [[ -d "$HOME/.icons/Papirus-Dark" ]]; then
        gtk-update-icon-cache -f "$HOME/.icons/Papirus-Dark" 2>/dev/null || true
    fi

    # Restart Thunar to apply changes
    echo "Restarting Thunar..."
    thunar --quit 2>/dev/null || true
    thunar & disown
else
    echo "papirus-folders not installed. Skipping Thunar icon update."
fi

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

echo "Done! Wallpaper, Waybar, and Thunar theme updated."
