#!/bin/bash
# setwall.sh - Random wallpaper setter + Pywal + Waybar + Yazi + Tofi theming
set -euo pipefail

# ----------------------------
# Directories
# ----------------------------
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
WAYBAR_CSS="$HOME/.config/waybar/colors.css"
PYWAL_CACHE="$HOME/.cache/wal/colors.css"
YAZI_THEME="$HOME/.config/yazi/theme.toml"
TOFI_TEMPLATE="$HOME/.config/tofi/tofi.template"
TOFI_OUTPUT="$HOME/.cache/wal/tofi"

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
COLOR15=$(grep color15 "$PYWAL_CACHE" | grep -o '#[0-9A-Fa-f]\{6\}' | head -n1)

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
# Update Yazi Theme
# ----------------------------
mkdir -p "$(dirname "$YAZI_THEME")"

cat > "$YAZI_THEME" <<EOF
[mgr]
fg = "$FG"
bg = "$BG"
border = "$COLOR2"
highlight = "$COLOR4"

[statusbar]
fg = "$FG"
bg = "$BG"

[preview]
fg = "$FG"
bg = "$BG"
EOF

echo "Yazi theme updated at $YAZI_THEME"

# ----------------------------
# Generate Tofi Theme
# ----------------------------
if [[ -f "$TOFI_TEMPLATE" ]]; then
    mkdir -p "$(dirname "$TOFI_OUTPUT")"
    
    sed \
        -e "s/{color0}/${BG}/g" \
        -e "s/{color4}/${COLOR4}/g" \
        -e "s/{color7}/${FG}/g" \
        -e "s/{color15}/${COLOR15}/g" \
        "$TOFI_TEMPLATE" > "$TOFI_OUTPUT"

    echo "Tofi theme generated at $TOFI_OUTPUT"
else
    echo "Warning: Tofi template not found at $TOFI_TEMPLATE, skipping Tofi theming."
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

# ----------------------------
# Reload Tofi Automatically
# ----------------------------
if pgrep -x "tofi-drun" >/dev/null; then
    echo "Reloading Tofi with new theme..."
    pkill -x tofi-drun
    # Relaunch in background if you want it to open immediately
    tofi-drun -c ~/.cache/wal/tofi --drun-launch=true &
else
    echo "Tofi is not currently running. No reload needed."
fi
echo "Done! Wallpaper, Waybar, Yazi, and Tofi theme updated."
